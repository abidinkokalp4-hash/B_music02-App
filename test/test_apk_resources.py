import importlib.util
import unittest
from pathlib import Path


spec = importlib.util.spec_from_file_location(
    'verify_resources',
    Path(__file__).resolve().parents[1] / 'tool/verify_apk_resources.py',
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ApkResourcesTest(unittest.TestCase):
    def resource_dump(self, omitted=()):
        return '\n'.join(
            f'    resource 0x7f070{index:03x} drawable/{name}'
            for index, name in enumerate(module.REQUIRED_MEDIA_ICONS)
            if name not in omitted
        )

    def test_all_media_icons_are_packaged(self):
        module.verify_resources(self.resource_dump())

    def test_missing_stop_icon_fails_even_when_notification_icon_is_present(self):
        with self.assertRaisesRegex(RuntimeError, 'audio_service_stop'):
            module.verify_resources(self.resource_dump(('audio_service_stop',)))

    def test_name_in_string_pool_does_not_count_as_a_drawable(self):
        dump = self.resource_dump(('audio_service_pause',))
        dump += '\nString #42: drawable/audio_service_pause\n'
        with self.assertRaisesRegex(RuntimeError, 'audio_service_pause'):
            module.verify_resources(dump)
