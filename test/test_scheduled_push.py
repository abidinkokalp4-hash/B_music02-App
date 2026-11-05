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

    def test_repository_file_is_valid(self):
        # The owner switches greetings on/off with this flag (on since b3ab511).
        self.assertIsInstance(self.config['enabled'], bool)
        self.assertEqual(self.config['slots']['morning']['time'], '08:30')
        self.assertEqual(self.config['slots']['evening']['time'], '21:00')

    def test_slots_follow_turkish_time(self):
        self.assertEqual(module.slot_for(at('2026-10-08T05:30:00+00:00')), 'morning')  # 08:30 TRT
        self.assertEqual(module.slot_for(at('2026-10-08T18:00:00+00:00')), 'evening')  # 21:00 TRT
        self.assertEqual(module.slot_for(at('2026-10-08T06:45:00+00:00')), 'morning')  # late cron
        self.assertEqual(module.slot_for(at('2026-10-08T12:00:00+00:00')), 'morning')  # 15:00 TRT still morning
        self.assertEqual(module.slot_for(at('2026-10-08T13:11:00+00:00')), 'morning')  # 16:11 TRT catch-up
        self.assertEqual(module.slot_for(at('2026-10-08T14:00:00+00:00')), 'evening')  # 17:00 TRT
        self.assertIsNone(module.slot_for(at('2026-10-08T01:06:00+03:00')))            # 01:06 TRT overnight miss

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
        disabled = dict(self.config, enabled=False)
        item, reason = module.plan(disabled, at('2026-10-08T08:30:00+03:00'))
        self.assertIsNone(item)
        self.assertIn('disabled', reason)
        with tempfile.TemporaryDirectory() as directory, \
                tempfile.NamedTemporaryFile('w+', delete=False) as out, \
                mock.patch.object(module.send_push, 'send') as send, redirect_stdout(io.StringIO()):
            config = Path(directory) / 'config.json'
            config.write_text(json.dumps(disabled, ensure_ascii=False))
            module.main(['--config', str(config), '--plan', '--now', '2026-10-08T08:30:00+03:00', '--github-output', out.name])
            module.main(['--config', str(config), '--send', '--now', '2026-10-08T08:30:00+03:00'])
            send.assert_not_called()
            self.assertEqual(Path(out.name).read_text().strip(), 'send=false')

    def test_enabled_config_validates_then_sends_one_push(self):
        enabled = dict(self.config, enabled=True)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'config.json'
            sent = Path(directory) / 'sent.json'
            path.write_text(json.dumps(enabled, ensure_ascii=False))
            sent.write_text(json.dumps({'sent': []}))
            output = Path(directory) / 'out'
            with mock.patch.object(module.send_push, 'send', return_value={'name': 'x'}) as send, redirect_stdout(io.StringIO()):
                module.main(['--config', str(path), '--sent', str(sent), '--plan',
                             '--now', '2026-10-29T05:35:00+00:00', '--github-output', str(output)])
                self.assertIn('id=auto-2026-10-29-morning', output.read_text())
                module.main(['--config', str(path), '--sent', str(sent), '--send',
                             '--now', '2026-10-29T05:35:00+00:00', '--access-token', 't'])
            self.assertEqual(send.call_count, 2)
            self.assertTrue(send.call_args_list[0].kwargs.get('validate_only'))
            message = send.call_args_list[1].args[1]['message']
            self.assertEqual(message['topic'], 'all')
            self.assertEqual(message['data']['id'], 'auto-2026-10-29-morning')
            self.assertIn('auto-2026-10-29-morning', json.loads(sent.read_text())['sent'])

    def test_invalid_config_is_rejected(self):
        broken = dict(self.config, special_days=[{'date': '2027-13-01', 'slot': 'morning', 'title': 'x'}])
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'c.json'
            path.write_text(json.dumps(broken))
            with self.assertRaises(ValueError):
                module.load(path)


    def test_already_sent_id_is_skipped_and_marked_after_send(self):
        enabled = dict(self.config, enabled=True)
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / 'config.json'
            sent = Path(directory) / 'sent.json'
            config.write_text(json.dumps(enabled, ensure_ascii=False))
            sent.write_text(json.dumps({'sent': []}))
            output = Path(directory) / 'out'
            with mock.patch.object(module.send_push, 'send', return_value={'name': 'x'}) as send, redirect_stdout(io.StringIO()):
                module.main(['--config', str(config), '--sent', str(sent), '--plan',
                             '--now', '2026-10-08T16:11:00+03:00', '--github-output', str(output)])
                self.assertIn('id=auto-2026-10-08-morning', output.read_text())
                module.main(['--config', str(config), '--sent', str(sent), '--send',
                             '--now', '2026-10-08T16:11:00+03:00', '--access-token', 't'])
            self.assertEqual(send.call_count, 2)
            self.assertIn('auto-2026-10-08-morning', json.loads(sent.read_text())['sent'])
            output2 = Path(directory) / 'out2'
            buf = io.StringIO()
            with mock.patch.object(module.send_push, 'send') as send2, redirect_stdout(buf):
                module.main(['--config', str(config), '--sent', str(sent), '--plan',
                             '--now', '2026-10-08T16:40:00+03:00', '--github-output', str(output2)])
                module.main(['--config', str(config), '--sent', str(sent), '--send',
                             '--now', '2026-10-08T16:40:00+03:00', '--access-token', 't'])
            self.assertEqual(output2.read_text().strip().splitlines()[0], 'send=false')
            self.assertIn('already sent (auto-2026-10-08-morning)', buf.getvalue())
            send2.assert_not_called()

    def test_dry_run_prints_without_network(self):
        with mock.patch.object(module.send_push, 'send') as send:
            buffer = io.StringIO()
            with redirect_stdout(buffer):
                module.main(['--dry-run', '--now', '2027-03-09T08:31:00+03:00'])
            send.assert_not_called()
        self.assertIn('Ramazan Bayram', buffer.getvalue())


if __name__ == '__main__':
    unittest.main()
