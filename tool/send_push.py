#!/usr/bin/env python3
"""Send a B Music announcement as an instant push (FCM HTTP v1, topic "all").

The same announcement (same id) can be appended to announcements.json with
--record, so phones that miss the push (old app version, battery restrictions,
no Google Play services) still get it from the ~4 h poll. The app notifies an
id only once, whichever path delivers it first.

Message format (data-only, so the app always handles it itself):
  id, title, body, url (optional, https only), createdAt

Authentication (first one found):
  --access-token / $ACCESS_TOKEN   OAuth token, e.g. from GitHub Actions
                                   google-github-actions/auth (keyless WIF)
  --key FILE / $FCM_SERVICE_ACCOUNT_FILE   service-account JSON key
  the Firebase CLI login on this machine (~/.config/configstore/firebase-tools.json)

Examples:
  tool/send_push.py --title "Yeni sürüm" --body "v1.0.340 hazır" --dry-run
  tool/send_push.py --title "Test" --token <device FCM token>
  tool/send_push.py --title "Yeni sürüm" --body "..." --record announcements.json

GitHub Actions (send-notification.yml) runs it in two steps so the fallback is
saved before anything is delivered:
  --record announcements.json --no-send   validate + write the entry
  (commit and push announcements.json to main with [skip ci])
  --send-recorded announcements.json --id ID   send exactly that entry
"""
import argparse
import base64
import datetime
import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

PROJECT = "bmusic02-app"
TOPIC = "all"
FIREBASE_CLI_CONFIG = Path.home() / ".config/configstore/firebase-tools.json"
SCOPE = "https://www.googleapis.com/auth/firebase.messaging"


def istanbul_now() -> datetime.datetime:
    # Türkiye is UTC+3 all year (no DST since 2016).
    return datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=3))).replace(microsecond=0)


def build_announcement(title, body="", url=None, ident=None, now=None):
    now = now or istanbul_now()
    title = (title or "").strip()
    if not title:
        raise ValueError("title is required")
    if len(title) > 120:
        raise ValueError("title is longer than 120 characters")
    body = (body or "").strip()
    if len(body) > 1000:
        raise ValueError("body is longer than 1000 characters")
    url = (url or "").strip() or None
    if url and not url.startswith("https://"):
        raise ValueError("url must start with https://")
    ident = (ident or "").strip() or now.strftime("%Y-%m-%d-%H%M%S")
    item = {"id": ident, "title": title}
    if body:
        item["body"] = body
    if url:
        item["url"] = url
    item["createdAt"] = now.isoformat()
    return item


def recorded(path, ident):
    root = json.loads(Path(path).read_text(encoding="utf-8"))
    for x in root.get("announcements", []):
        if isinstance(x, dict) and x.get("id") == ident:
            return build_announcement(x.get("title"), x.get("body"), x.get("url"), ident,
                                      datetime.datetime.fromisoformat(x["createdAt"]) if x.get("createdAt") else None)
    raise ValueError(f"id {ident} not found in {path}")


def build_message(item, topic=TOPIC, token=None):
    data = {k: str(v) for k, v in item.items()}
    message = {
        "data": data,
        # High priority wakes the app in Doze so the notification shows at once;
        # FCM keeps it up to 7 days for phones that are offline.
        "android": {"priority": "HIGH", "ttl": "604800s"},
    }
    if token:
        message["token"] = token
    else:
        message["topic"] = topic
    if len(json.dumps(data).encode()) > 3800:
        raise ValueError("announcement is too large for one push (4 KB limit)")
    return {"message": message}


def record(path, item):
    """Insert the announcement at the top of announcements.json (same id as the push)."""
    path = Path(path)
    root = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {"announcements": []}
    items = root.setdefault("announcements", [])
    if any(isinstance(x, dict) and x.get("id") == item["id"] for x in items):
        raise ValueError(f"id {item['id']} already exists in {path}")
    items.insert(0, item)
    path.write_text(json.dumps(root, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def _b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def token_from_key(key_file):
    key = json.loads(Path(key_file).read_text())
    now = int(time.time())
    header = _b64(json.dumps({"alg": "RS256", "typ": "JWT"}).encode())
    claims = _b64(json.dumps({"iss": key["client_email"], "scope": SCOPE, "aud": key["token_uri"],
                              "iat": now, "exp": now + 3600}).encode())
    unsigned = f"{header}.{claims}".encode()
    with tempfile.NamedTemporaryFile("w", delete=False) as pem:
        os.chmod(pem.name, 0o600)
        pem.write(key["private_key"])
    try:
        signature = subprocess.run(["openssl", "dgst", "-sha256", "-sign", pem.name], input=unsigned,
                                   capture_output=True, check=True).stdout
    finally:
        os.unlink(pem.name)
    body = urllib.parse.urlencode({"grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
                                   "assertion": unsigned.decode() + "." + _b64(signature)}).encode()
    with urllib.request.urlopen(urllib.request.Request(key["token_uri"], data=body)) as response:
        return json.load(response)["access_token"]


def token_from_firebase_cli():
    if not FIREBASE_CLI_CONFIG.exists():
        return None
    config = json.loads(FIREBASE_CLI_CONFIG.read_text())
    if config.get("tokens", {}).get("expires_at", 0) / 1000 - time.time() < 300:
        # Any authenticated CLI command refreshes the stored token.
        subprocess.run("npx -y firebase-tools@latest projects:list", shell=True, capture_output=True)
        config = json.loads(FIREBASE_CLI_CONFIG.read_text())
    return config.get("tokens", {}).get("access_token")


def credentials(args):
    if args.access_token:
        return args.access_token, False
    if args.key:
        return token_from_key(args.key), False
    token = token_from_firebase_cli()
    if token:
        return token, True
    raise SystemExit("No credentials: pass --access-token, --key or log in with the Firebase CLI")


def send(project, payload, access_token, user_credentials=False, validate_only=False):
    body = dict(payload, validate_only=True) if validate_only else payload
    request = urllib.request.Request(f"https://fcm.googleapis.com/v1/projects/{project}/messages:send",
                                     data=json.dumps(body).encode(), method="POST")
    request.add_header("Authorization", "Bearer " + access_token)
    request.add_header("Content-Type", "application/json; charset=utf-8")
    if user_credentials:
        request.add_header("x-goog-user-project", project)
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        detail = error.read().decode(errors="replace")
        raise SystemExit(f"FCM error {error.code}: {detail}")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--title")
    parser.add_argument("--body", default="")
    parser.add_argument("--url", default="")
    parser.add_argument("--id", default="", help="default: date-time in Istanbul, e.g. 2026-10-07-221500")
    target = parser.add_mutually_exclusive_group()
    target.add_argument("--topic", default=TOPIC)
    target.add_argument("--token", help="one device's FCM registration token (for tests)")
    parser.add_argument("--project", default=os.environ.get("FCM_PROJECT", PROJECT))
    parser.add_argument("--access-token", default=os.environ.get("ACCESS_TOKEN"))
    parser.add_argument("--key", default=os.environ.get("FCM_SERVICE_ACCOUNT_FILE"))
    parser.add_argument("--dry-run", action="store_true", help="validate only (FCM validate_only), deliver nothing")
    parser.add_argument("--record", metavar="ANNOUNCEMENTS_JSON",
                        help="also add the announcement to this announcements.json (skipped with --dry-run)")
    parser.add_argument("--no-send", action="store_true", help="validate (and --record) only")
    parser.add_argument("--send-recorded", metavar="ANNOUNCEMENTS_JSON",
                        help="send the entry with --id from this file (written earlier with --record)")
    parser.add_argument("--github-output", default=os.environ.get("GITHUB_OUTPUT"))
    args = parser.parse_args(argv)
    try:
        if args.send_recorded:
            if not args.id:
                raise ValueError("--send-recorded needs --id")
            item = recorded(args.send_recorded, args.id)
        else:
            item = build_announcement(args.title, args.body, args.url, args.id)
        payload = build_message(item, topic=args.topic, token=args.token)
    except ValueError as error:
        raise SystemExit(f"Invalid announcement: {error}")
    access_token, user = credentials(args)
    # Always validate first: proves credentials and message before anything is written.
    checked = send(args.project, payload, access_token, user, validate_only=True)
    print(f"validate_only OK ({checked.get('name', '?')}) id={item['id']} target="
          + (f"topic:{args.topic}" if not args.token else "token"))
    if args.github_output:
        with open(args.github_output, "a") as out:
            out.write(f"id={item['id']}\n")
    if args.dry_run:
        print("dry run: nothing sent, announcements.json unchanged")
        return item
    if args.record:
        record(args.record, item)
        print(f"recorded in {args.record}")
    if args.no_send:
        return item
    result = send(args.project, payload, access_token, user)
    print(f"sent: {result.get('name')}")
    return item


if __name__ == "__main__":
    main()
