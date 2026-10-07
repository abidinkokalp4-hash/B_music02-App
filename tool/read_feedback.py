#!/usr/bin/env python3
"""Read the Öneri Kutusu (in-app feedback) messages from Firestore.

Phones can only *create* documents in the `feedback` collection (see
firestore.rules); reading needs the owner's Google login. This script uses the
Firebase CLI login on this machine (`npx -y firebase-tools@latest login`, as
abidinkokalp4@gmail.com) — no keys are stored anywhere.

  python3 tool/read_feedback.py                # newest 50 messages
  python3 tool/read_feedback.py --limit 200
  python3 tool/read_feedback.py --json         # raw JSON (for scripts)
  python3 tool/read_feedback.py --delete ID    # remove one message (e.g. spam)

The same messages are visible in the Firebase console:
Firestore Database → Data → feedback.
"""
import argparse
import datetime
import json
import subprocess
import time
import urllib.error
import urllib.request
from pathlib import Path

PROJECT = "bmusic02-app"
BASE = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents"
CLI = Path.home() / ".config/configstore/firebase-tools.json"
ISTANBUL = datetime.timezone(datetime.timedelta(hours=3))


def access_token() -> str:
    if not CLI.exists():
        raise SystemExit("Firebase CLI login missing: run `npx -y firebase-tools@latest login`")
    config = json.loads(CLI.read_text())
    if config.get("tokens", {}).get("expires_at", 0) / 1000 - time.time() < 300:
        subprocess.run("npx -y firebase-tools@latest projects:list", shell=True, capture_output=True)
        config = json.loads(CLI.read_text())
    return config["tokens"]["access_token"]


def call(method: str, url: str, body=None):
    request = urllib.request.Request(url, method=method,
                                     data=None if body is None else json.dumps(body).encode())
    request.add_header("Authorization", "Bearer " + access_token())
    request.add_header("x-goog-user-project", PROJECT)
    request.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.loads(response.read() or b"{}")
    except urllib.error.HTTPError as error:
        raise SystemExit(f"Firestore error {error.code}: {error.read().decode(errors='replace')}")


def value(field: dict):
    for kind in ("stringValue", "integerValue", "timestampValue", "booleanValue", "doubleValue"):
        if kind in field:
            return field[kind]
    return None


def parse(document: dict) -> dict:
    fields = {k: value(v) for k, v in document.get("fields", {}).items()}
    fields["id"] = document["name"].rsplit("/", 1)[-1]
    fields.setdefault("createdAt", document.get("createTime"))
    return fields


def local_time(stamp: str) -> str:
    try:
        moment = datetime.datetime.fromisoformat(stamp.replace("Z", "+00:00"))
        return moment.astimezone(ISTANBUL).strftime("%d.%m.%Y %H:%M") + " (TSİ)"
    except (AttributeError, ValueError):
        return stamp or "?"


def fetch(limit: int) -> list:
    query = {"structuredQuery": {"from": [{"collectionId": "feedback"}],
                                 "orderBy": [{"field": {"fieldPath": "createdAt"}, "direction": "DESCENDING"}],
                                 "limit": limit}}
    rows = call("POST", f"{BASE}:runQuery", query)
    return [parse(row["document"]) for row in rows if "document" in row]


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--limit", type=int, default=50)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--delete", metavar="ID")
    args = parser.parse_args(argv)
    if args.delete:
        call("DELETE", f"{BASE}/feedback/{args.delete}")
        print(f"deleted {args.delete}")
        return
    items = fetch(args.limit)
    if args.json:
        print(json.dumps(items, ensure_ascii=False, indent=2))
        return
    if not items:
        print("Henüz öneri yok.")
        return
    for item in items:
        meta = " · ".join(x for x in (item.get("appVersion") and "v" + item["appVersion"],
                                       item.get("android") and "Android API " + str(item["android"]),
                                       item.get("device")) if x)
        print(f"── {local_time(item.get('createdAt'))}  [{item['id']}]  {meta}")
        if item.get("contact"):
            print(f"   İletişim: {item['contact']}")
        print("   " + (item.get("message") or "").replace("\n", "\n   "))
        print()
    print(f"{len(items)} mesaj")


if __name__ == "__main__":
    main()
