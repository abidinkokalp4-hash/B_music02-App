import datetime
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location('send_push', Path(__file__).resolve().parents[1] / 'tool/send_push.py')
send_push = importlib.util.module_from_spec(spec)
spec.loader.exec_module(send_push)

NOW = datetime.datetime(2026, 10, 7, 22, 15, 0, tzinfo=datetime.timezone(datetime.timedelta(hours=3)))


class SendPushTest(unittest.TestCase):
    def test_announcement_fields_and_validation(self):
        item = send_push.build_announcement(' Yeni sürüm ', ' Hazır ', 'https://example.com', now=NOW)
        self.assertEqual(item, {'id': '2026-10-07-221500', 'title': 'Yeni sürüm', 'body': 'Hazır',
                                'url': 'https://example.com', 'createdAt': '2026-10-07T22:15:00+03:00'})
        self.assertNotIn('url', send_push.build_announcement('t', now=NOW))
        self.assertEqual(send_push.build_announcement('t', ident='custom', now=NOW)['id'], 'custom')
        for bad in [dict(title=''), dict(title='x' * 121), dict(title='t', body='b' * 1001), dict(title='t', url='http://x')]:
            with self.assertRaises(ValueError):
                send_push.build_announcement(now=NOW, **bad)

    def test_message_is_data_only_high_priority_topic_or_token(self):
        item = send_push.build_announcement('Başlık', 'Metin', now=NOW)
        message = send_push.build_message(item)['message']
        self.assertEqual(message['topic'], 'all')
        self.assertNotIn('notification', message)
        self.assertEqual(message['data']['id'], item['id'])
        self.assertTrue(all(isinstance(v, str) for v in message['data'].values()))
        self.assertEqual(message['android']['priority'], 'HIGH')
        direct = send_push.build_message(item, token='abc')['message']
        self.assertEqual(direct['token'], 'abc')
        self.assertNotIn('topic', direct)

    def test_record_inserts_on_top_once_and_send_recorded_reuses_it(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'announcements.json'
            path.write_text(json.dumps({'announcements': [{'id': 'old', 'title': 'Eski'}]}))
            item = send_push.build_announcement('Yeni', 'Metin', 'https://e.com', now=NOW)
            send_push.record(path, item)
            data = json.loads(path.read_text())
            self.assertEqual([x['id'] for x in data['announcements']], [item['id'], 'old'])
            with self.assertRaises(ValueError):
                send_push.record(path, item)
            self.assertEqual(send_push.recorded(path, item['id']), item)
            with self.assertRaises(ValueError):
                send_push.recorded(path, 'missing')

    def test_repository_feed_is_valid(self):
        feed = json.loads((Path(__file__).resolve().parents[1] / 'announcements.json').read_text())
        ids = [x['id'] for x in feed['announcements']]
        self.assertEqual(len(ids), len(set(ids)))


if __name__ == '__main__':
    unittest.main()
