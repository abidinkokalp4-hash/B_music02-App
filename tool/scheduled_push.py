#!/usr/bin/env python3
"""Scheduled B Music greetings (günaydın, iyi akşamlar, Hayırlı Cumalar, special days).

Run by .github/workflows/send-notification.yml on its `schedule:` crons
(05:30 and 18:00 UTC = 08:30 and 21:00 in Türkiye). Everything is driven by
scheduled_notifications.json; with "enabled": false the workflow stops here,
before any Google sign-in, and nothing is sent.

Each run sends at most one push to FCM topic "all" with a deterministic id
"auto-YYYY-MM-DD-morning|evening", so a duplicated cron run can never show the
same greeting twice (the app notifies an id once). Greetings are push-only:
they are not written to announcements.json and the app does not keep them in
the Duyurular list.

  tool/scheduled_push.py --dry-run                 what would go out now (offline)
  tool/scheduled_push.py --dry-run --now 2027-03-09T08:31:00+03:00
  tool/scheduled_push.py --list 14                 the next 14 days (offline)
  tool/scheduled_push.py --plan                    GitHub step: writes send/id/title
  tool/scheduled_push.py --send                    validate, then send (needs ACCESS_TOKEN)
"""
import argparse
import datetime
import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import send_push  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "scheduled_notifications.json"
TRT = datetime.timezone(datetime.timedelta(hours=3))  # Türkiye: UTC+3 all year
SLOTS = ("morning", "evening")
# GitHub may start scheduled runs late; accept a generous window per slot.
WINDOWS = {"morning": range(5, 14), "evening": range(17, 24)}


def load(path=CONFIG):
    config = json.loads(Path(path).read_text(encoding="utf-8"))
    if not isinstance(config.get("enabled"), bool):
        raise ValueError('"enabled" must be true or false')
    slots = config.get("slots") or {}
    for name in (*SLOTS, "friday"):
        messages = (slots.get(name) or {}).get("messages") or []
        if not messages:
            raise ValueError(f"slots.{name}.messages is empty")
        for m in messages:
            send_push.build_announcement(m.get("title"), m.get("body"), ident="check")
    if (slots["friday"].get("slot") or "morning") not in SLOTS:
        raise ValueError("slots.friday.slot must be morning or evening")
    seen = set()
    for day in config.get("special_days") or []:
        datetime.date.fromisoformat(day["date"])
        if day.get("slot") not in SLOTS:
            raise ValueError(f"{day['date']}: slot must be morning or evening")
        if (day["date"], day["slot"]) in seen:
            raise ValueError(f"{day['date']} {day['slot']}: more than one special message")
        seen.add((day["date"], day["slot"]))
        send_push.build_announcement(day.get("title"), day.get("body"), ident="check")
    return config


def slot_for(now):
    hour = now.astimezone(TRT).hour
    return next((name for name, hours in WINDOWS.items() if hour in hours), None)


def pick(config, now, slot):
    """The single greeting for this day and slot: special day > Friday > rotation."""
    today = now.astimezone(TRT).date()
    for day in config.get("special_days") or []:
        if day["date"] == today.isoformat() and day["slot"] == slot:
            message, kind = day, "special"
            break
    else:
        friday = config["slots"]["friday"]
        if today.weekday() == 4 and (friday.get("slot") or "morning") == slot:
            pool, kind = friday["messages"], "friday"
        else:
            pool, kind = config["slots"][slot]["messages"], "daily"
        # Rotate by date so consecutive days differ and reruns pick the same text.
        message = pool[today.toordinal() % len(pool)]
    ident = f"auto-{today.isoformat()}-{slot}"
    stamp = datetime.datetime.combine(today, datetime.time.fromisoformat(config["slots"][slot]["time"]), TRT)
    item = send_push.build_announcement(message["title"], message.get("body", ""), message.get("url"), ident, stamp)
    return item, kind


def plan(config, now, slot=None):
    slot = slot or slot_for(now)
    if not config["enabled"]:
        return None, "disabled (scheduled_notifications.json: \"enabled\": false)"
    if slot is None:
        return None, f"outside the greeting windows ({now.astimezone(TRT):%H:%M} TRT)"
    item, kind = pick(config, now, slot)
    return item, kind


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--config", default=str(CONFIG))
    parser.add_argument("--now", help="ISO time for tests, e.g. 2027-03-09T08:31:00+03:00")
    parser.add_argument("--slot", choices=SLOTS, help="force a slot (default: from the time)")
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--dry-run", action="store_true", help="print the greeting; no network, ignores enabled")
    mode.add_argument("--list", type=int, metavar="DAYS", help="print the next DAYS days (offline)")
    mode.add_argument("--plan", action="store_true", help="GitHub step: write send=true|false, id, title")
    mode.add_argument("--send", action="store_true", help="validate with FCM, then send to topic all")
    parser.add_argument("--project", default=os.environ.get("FCM_PROJECT", send_push.PROJECT))
    parser.add_argument("--access-token", default=os.environ.get("ACCESS_TOKEN"))
    parser.add_argument("--github-output", default=os.environ.get("GITHUB_OUTPUT"))
    args = parser.parse_args(argv)
    config = load(args.config)
    now = datetime.datetime.fromisoformat(args.now) if args.now else datetime.datetime.now(TRT)
    if now.tzinfo is None:
        now = now.replace(tzinfo=TRT)
    if args.list:
        print(f"enabled={config['enabled']}")
        start = now.astimezone(TRT).date()
        for offset in range(args.list):
            day = start + datetime.timedelta(days=offset)
            for slot in SLOTS:
                at = datetime.datetime.combine(day, datetime.time.fromisoformat(config["slots"][slot]["time"]), TRT)
                item, kind = pick(config, at, slot)
                print(f"{day:%Y-%m-%d %a} {config['slots'][slot]['time']} TRT [{kind}] {item['title']} — {item.get('body', '')}")
        return 0
    if args.dry_run:
        slot = args.slot or slot_for(now)
        if slot is None:
            print(f"outside the greeting windows ({now.astimezone(TRT):%H:%M} TRT); nothing would be sent")
            return 0
        item, kind = pick(config, now, slot)
        print(f"enabled={config['enabled']} slot={slot} kind={kind}")
        print(json.dumps(send_push.build_message(item), ensure_ascii=False, indent=2))
        print("dry run: nothing sent")
        return 0
    item, reason = plan(config, now, args.slot)
    if args.plan:
        lines = [f"send={'true' if item else 'false'}"]
        if item:
            lines += [f"id={item['id']}", f"title={item['title']}", f"kind={reason}"]
            print(f"will send {item['id']} [{reason}]: {item['title']}")
        else:
            print("nothing to send: " + reason)
        if args.github_output:
            with open(args.github_output, "a", encoding="utf-8") as out:
                out.write("\n".join(lines) + "\n")
        return 0
    if not item:
        print("nothing to send: " + reason)
        return 0
    if not args.access_token:
        raise SystemExit("--send needs ACCESS_TOKEN (GitHub: google-github-actions/auth)")
    payload = send_push.build_message(item)
    checked = send_push.send(args.project, payload, args.access_token, validate_only=True)
    print(f"validate_only OK ({checked.get('name', '?')}) id={item['id']}")
    result = send_push.send(args.project, payload, args.access_token)
    print(f"sent: {result.get('name')} id={item['id']} [{reason}] {item['title']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
