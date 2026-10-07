import datetime
import io
import json
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tool'))
import scheduled_push as module  # noqa: E402

TRT = module.TRT


def at(text):
    return datetime.datetime.fromisoformat(text)


class ScheduledPushTest(unittest.TestCase):
    def setUp(self):
        self.config = module.load()

    def test_repository_file_is_valid_and_disabled(self):
        self.assertFalse(self.config['enabled'], 'Scheduled greetings must stay off until the owner enables them')
        self.assertEqual(self.config['slots']['morning']['time'], '08:30')
        self.assertEqual(self.config['slots']['evening']['time'], '21:00')

    def test_slots_follow_turkish_time(self):
        self.assertEqual(module.slot_for(at('2026-10-08T05:30:00+00:00')), 'morning')  # 08:30 TRT
        self.assertEqual(module.slot_for(at('2026-10-08T18:00:00+00:00')), 'evening')  # 21:00 TRT
        self.assertEqual(module.slot_for(at('2026-10-08T06:45:00+00:00')), 'morning')  # late cron
        self.assertIsNone(module.slot_for(at('2026-10-08T12:00:00+00:00')))            # 15:00 TRT

    def test_friday_morning_is_hayirli_cumalar(self):
        item, kind = module.pick(self.config, at('2026-10-09T08:31:00+03:00'), 'morning')
        self.assertEqual(kind, 'friday')
        self.assertIn('Cuma', item['title'])
        self.assertEqual(item['id'], 'auto-2026-10-09-morning')
        _, evening = module.pick(self.config, at('2026-10-09T21:00:00+03:00'), 'evening')
        self.assertEqual(evening, 'daily')

    def test_special_days_replace_the_daily_text(self):
        cases = {
            ('2026-10-29T08:30:00+03:00', 'morning'): 'Cumhuriyet',
            ('2026-12-10T21:00:00+03:00', 'evening'): 'Regaib',
            ('2027-01-04T21:00:00+03:00', 'evening'): 'Miraç',
            ('2027-01-22T21:00:00+03:00', 'evening'): 'Berat',
            ('2027-03-09T08:30:00+03:00', 'morning'): 'Ramazan Bayram',
            ('2027-05-16T08:30:00+03:00', 'morning'): 'Kurban Bayram',
            ('2027-08-13T21:00:00+03:00', 'evening'): 'Mevlid',
        }
        for (when, slot), expected in cases.items():
            item, kind = module.pick(self.config, at(when), slot)
            self.assertEqual(kind, 'special', when)
            self.assertIn(expected, item['title'], when)
        # Berat Kandili is a Friday: the morning still says Hayırlı Cumalar.
        self.assertEqual(module.pick(self.config, at('2027-01-22T08:30:00+03:00'), 'morning')[1], 'friday')

    def test_rotation_changes_daily_and_is_stable(self):
        a, _ = module.pick(self.config, at('2026-10-07T08:30:00+03:00'), 'morning')
        b, _ = module.pick(self.config, at('2026-10-08T08:30:00+03:00'), 'morning')
        again, _ = module.pick(self.config, at('2026-10-07T09:10:00+03:00'), 'morning')
        self.assertNotEqual(a['title'] + a['body'], b['title'] + b['body'])
        self.assertEqual(a, again)
        self.assertEqual(a['createdAt'], '2026-10-07T08:30:00+03:00')

    def test_disabled_config_plans_nothing_and_never_sends(self):
        item, reason = module.plan(self.config, at('2026-10-08T08:30:00+03:00'))
        self.assertIsNone(item)
        self.assertIn('disabled', reason)
        with tempfile.NamedTemporaryFile('w+', delete=False) as out, \
                mock.patch.object(module.send_push, 'send') as send, redirect_stdout(io.StringIO()):
            module.main(['--plan', '--now', '2026-10-08T08:30:00+03:00', '--github-output', out.name])
            module.main(['--send', '--now', '2026-10-08T08:30:00+03:00'])
            send.assert_not_called()
            self.assertEqual(Path(out.name).read_text().strip(), 'send=false')

    def test_enabled_config_validates_then_sends_one_push(self):
        enabled = dict(self.config, enabled=True)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'config.json'
            path.write_text(json.dumps(enabled, ensure_ascii=False))
            output = Path(directory) / 'out'
            with mock.patch.object(module.send_push, 'send', return_value={'name': 'x'}) as send, redirect_stdout(io.StringIO()):
                module.main(['--config', str(path), '--plan', '--now', '2026-10-29T05:35:00+00:00', '--github-output', str(output)])
                self.assertIn('id=auto-2026-10-29-morning', output.read_text())
                module.main(['--config', str(path), '--send', '--now', '2026-10-29T05:35:00+00:00', '--access-token', 't'])
            self.assertEqual(send.call_count, 2)
            self.assertTrue(send.call_args_list[0].kwargs.get('validate_only'))
            message = send.call_args_list[1].args[1]['message']
            self.assertEqual(message['topic'], 'all')
            self.assertEqual(message['data']['id'], 'auto-2026-10-29-morning')

    def test_invalid_config_is_rejected(self):
        broken = dict(self.config, special_days=[{'date': '2027-13-01', 'slot': 'morning', 'title': 'x'}])
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'c.json'
            path.write_text(json.dumps(broken))
            with self.assertRaises(ValueError):
                module.load(path)

    def test_dry_run_prints_without_network(self):
        with mock.patch.object(module.send_push, 'send') as send:
            buffer = io.StringIO()
            with redirect_stdout(buffer):
                module.main(['--dry-run', '--now', '2027-03-09T08:31:00+03:00'])
            send.assert_not_called()
        self.assertIn('Ramazan Bayram', buffer.getvalue())


if __name__ == '__main__':
    unittest.main()
