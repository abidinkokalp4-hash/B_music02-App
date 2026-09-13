"""Prepare missing native platforms without deleting existing native customisations."""
from pathlib import Path
import plistlib
import subprocess

from configure_android import main as configure_android

ROOT = Path(__file__).resolve().parents[1]


def main():
    missing = [name for name in ('android', 'ios') if not (ROOT / name).exists()]
    generated_test = ROOT / 'test/widget_test.dart'
    had_widget_test = generated_test.exists()
    if missing:
        subprocess.run([
            'flutter', 'create', '--platforms=' + ','.join(missing),
            '--org', 'com.example', '--project-name', 'b_music02', '--no-pub', '.',
        ], cwd=ROOT, check=True)
        if not had_widget_test and generated_test.exists():
            generated_test.unlink()
    subprocess.run(['flutter', 'pub', 'get'], cwd=ROOT, check=True)
    configure_android()
    plist = ROOT / 'ios/Runner/Info.plist'
    if plist.exists():
        with plist.open('rb') as file:
            data = plistlib.load(file)
        data['NSPhotoLibraryUsageDescription'] = 'Profil fotoğrafınızı seçmek için fotoğraf erişimi gerekir.'
        data['NSAppleMusicUsageDescription'] = 'Müzik arşivinizi listelemek için erişim gerekir.'
        data['UIBackgroundModes'] = list(set(data.get('UIBackgroundModes', []) + ['audio']))
        with plist.open('wb') as file:
            plistlib.dump(data, file, sort_keys=False)


if __name__ == '__main__':
    main()
