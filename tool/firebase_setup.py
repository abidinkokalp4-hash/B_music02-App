#!/usr/bin/env python3
"""One-time Firebase setup for B Music push (run on a machine with the Firebase CLI logged in).

Adds Firebase to the Google Cloud project (Spark plan, no billing), registers
the Android app com.example.b_music02 with the release signing certificate
fingerprints and writes lib/firebase_options.dart. Safe to re-run.

  tool/firebase_setup.py [--project bmusic02-app] [--sha1 HEX]
"""
import argparse
import base64
import json
import re
import subprocess
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
API = "https://firebase.googleapis.com/v1beta1"
PACKAGE = "com.example.b_music02"
CLI = Path.home() / ".config/configstore/firebase-tools.json"


def token():
    config = json.loads(CLI.read_text())
    if config["tokens"]["expires_at"] / 1000 - time.time() < 300:
        subprocess.run("npx -y firebase-tools@latest projects:list", shell=True, capture_output=True)
        config = json.loads(CLI.read_text())
    return config["tokens"]["access_token"]


def call(method, url, body=None):
    request = urllib.request.Request(url, data=None if body is None else json.dumps(body).encode(), method=method)
    request.add_header("Authorization", "Bearer " + token())
    request.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(request) as response:
            return response.status, json.loads(response.read() or b"{}")
    except urllib.error.HTTPError as error:
        return error.code, json.loads(error.read() or b"{}")


def wait(operation):
    while not operation.get("done"):
        time.sleep(3)
        _, operation = call("GET", f"{API}/{operation['name']}")
    if "error" in operation:
        raise SystemExit(f"Operation failed: {operation['error']}")
    return operation.get("response", {})


def ensure_firebase(project):
    status, info = call("GET", f"{API}/projects/{project}")
    if status == 200:
        return info
    status, op = call("POST", f"{API}/projects/{project}:addFirebase", {})
    if status == 403:
        raise SystemExit("addFirebase was refused (403). Open https://console.firebase.google.com/?forceCheckTos=true "
                         "signed in as the project owner, accept the Firebase Terms of Service, then re-run.")
    if status != 200:
        raise SystemExit(f"addFirebase failed: {status} {op}")
    return wait(op)


def ensure_android_app(project):
    _, apps = call("GET", f"{API}/projects/{project}/androidApps")
    for app in apps.get("apps", []):
        if app.get("packageName") == PACKAGE:
            return app
    status, op = call("POST", f"{API}/projects/{project}/androidApps", {"packageName": PACKAGE, "displayName": "B Music Android"})
    if status != 200:
        raise SystemExit(f"Android app registration failed: {status} {op}")
    return wait(op)


def ensure_sha(project, app_id, hashes):
    _, existing = call("GET", f"{API}/projects/{project}/androidApps/{app_id}/sha")
    have = {c["shaHash"].lower() for c in existing.get("certificates", [])}
    for value in hashes:
        value = value.replace(":", "").lower()
        if value in have:
            continue
        kind = "SHA_1" if len(value) == 40 else "SHA_256"
        status, result = call("POST", f"{API}/projects/{project}/androidApps/{app_id}/sha", {"shaHash": value, "certType": kind})
        print(f"SHA {kind}: {status}")
        if status != 200:
            raise SystemExit(f"Adding {kind} failed: {result}")


def write_options(config):
    client = next(c for c in config["client"] if c["client_info"]["android_client_info"]["package_name"] == PACKAGE)
    values = {
        "apiKey": client["api_key"][0]["current_key"],
        "appId": client["client_info"]["mobilesdk_app_id"],
        "messagingSenderId": config["project_info"]["project_number"],
        "projectId": config["project_info"]["project_id"],
    }
    path = ROOT / "lib/firebase_options.dart"
    text = path.read_text()
    for key, value in values.items():
        text, count = re.subn(rf"({key}:\s*)'[^']*'", rf"\g<1>'{value}'", text, count=1)
        if count != 1:
            raise SystemExit(f"{key} not found in {path}")
    path.write_text(text)
    print(f"lib/firebase_options.dart updated: project={values['projectId']} appId={values['appId']}")
    return values


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--project", default="bmusic02-app")
    parser.add_argument("--sha1", action="append", default=[], help="extra SHA-1 fingerprint(s) of the signing key")
    args = parser.parse_args()
    ensure_firebase(args.project)
    app = ensure_android_app(args.project)
    app_id = app["appId"]
    print(f"Android app: {app_id}")
    pinned = (ROOT / "tool/release_signing_cert.sha256").read_text().strip()
    ensure_sha(args.project, app_id, [pinned, *args.sha1])
    _, config = call("GET", f"{API}/projects/{args.project}/androidApps/{app_id}/config")
    write_options(json.loads(base64.b64decode(config["configFileContents"])))


if __name__ == "__main__":
    main()
