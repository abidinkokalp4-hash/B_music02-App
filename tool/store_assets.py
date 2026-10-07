#!/usr/bin/env python3
"""Google Play listing graphics for B Music (store/).

    python3 tool/store_assets.py                 # icon + feature graphic
    python3 tool/store_assets.py --frame DIR     # + captioned copies of DIR/*.png

* store/icon-512.png             512x512 app icon (from assets/images/b_music02_logo.png)
* store/feature-graphic.png      1024x500 feature graphic
* store/screenshots/framed/*.png 1080x1920 screenshots with a short Turkish caption
  (raw screenshots come from the CI emulator: tool/capture_store_screenshots.py)

Fonts: Poppins (SIL Open Font License); any TTF path can be given with --font-dir.
"""
import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
STORE = ROOT / 'store'
LOGO = ROOT / 'assets/images/b_music02_logo.png'
LOGO_BOX = (79, 84, 1175, 1161)          # the rounded square without the black margin
FONT_DIR = Path('/usr/share/fonts/truetype/sand-box/google/Poppins')
BG = (3, 3, 5)
DEEP = (27, 8, 46)
ACCENT = (165, 60, 255)
CAPTIONS = {
    '01-home': ('Müziğin ve videoların', 'tek yerde'),
    '02-music': ('Tüm şarkıların', 'düzenli ve hızlı'),
    '03-player': ('Şık müzik çalar', 'kilit ekranında da kontrol'),
    '04-videos': ('Telefondaki videolar', 'klasörlere göre'),
    '05-video-player': ('Sade video oynatıcı', 'kaydır, sonraki video'),
    '06-video-tools': ('Tek menüde', 'hız, kırp, GIF, ses kaydet'),
    '07-alarm': ('Sevdiğin şarkıyla', 'uyan'),
    '08-settings': ('Basit ayarlar', 'reklam yok'),
}


def font(name, size, font_dir=FONT_DIR):
    return ImageFont.truetype(str(font_dir / f'Poppins-{name}.ttf'), size)


def logo(size):
    image = Image.open(LOGO).convert('RGB').crop(LOGO_BOX)
    return image.resize((size, size), Image.LANCZOS)


def rounded(image, radius):
    mask = Image.new('L', image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, *image.size), radius, fill=255)
    out = Image.new('RGBA', image.size)
    out.paste(image, (0, 0), mask)
    return out


def glow_background(size, centre, radius, colour=ACCENT, strength=150):
    base = Image.new('RGB', size, BG)
    # vertical deep-purple gradient
    top = Image.new('RGB', size, DEEP)
    mask = Image.linear_gradient('L').resize(size).rotate(180)
    base = Image.composite(top, base, mask.point(lambda v: v * 0.8))
    glow = Image.new('L', size, 0)
    cx, cy = centre
    ImageDraw.Draw(glow).ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=strength)
    glow = glow.filter(ImageFilter.GaussianBlur(radius * 0.6))
    return Image.composite(Image.new('RGB', size, colour), base, glow)


def icon():
    out = STORE / 'icon-512.png'
    logo(512).save(out, optimize=True)
    return out


def feature_graphic(font_dir=FONT_DIR):
    size = (1024, 500)
    image = glow_background(size, (250, 250), 260).convert('RGBA')
    mark = rounded(logo(300), 54)
    shadow = Image.new('RGBA', (360, 360), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((30, 30, 330, 330), 54, fill=(0, 0, 0, 170))
    image.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(16)), (70, 82))
    image.alpha_composite(mark, (100, 100))
    draw = ImageDraw.Draw(image)
    draw.text((460, 128), 'B Music', font=font('Bold', 96, font_dir), fill='white')
    draw.text((464, 252), 'Müzik ve Video Oynatıcı', font=font('Medium', 38, font_dir), fill=(226, 205, 255))
    draw.text((466, 322), 'Müzik  •  Video  •  Alarm', font=font('Regular', 30, font_dir), fill=(200, 190, 215))
    out = STORE / 'feature-graphic.png'
    image.convert('RGB').save(out, optimize=True)
    return out


def frame(shot, caption, out, font_dir=FONT_DIR):
    size = (1080, 1920)
    image = glow_background(size, (540, 260), 420, strength=120).convert('RGBA')
    draw = ImageDraw.Draw(image)
    title, subtitle = caption
    for text, y, f, colour in ((title, 70, font('Bold', 66, font_dir), 'white'),
                               (subtitle, 158, font('Medium', 44, font_dir), (220, 196, 255))):
        width = draw.textlength(text, font=f)
        draw.text(((size[0] - width) / 2, y), text, font=f, fill=colour)
    phone = Image.open(shot).convert('RGB')
    height = 1600
    width = round(phone.width * height / phone.height)
    phone = rounded(phone.resize((width, height), Image.LANCZOS), 48)
    x, y = (size[0] - width) // 2, 270
    border = Image.new('RGBA', (width + 24, height + 24), (0, 0, 0, 0))
    ImageDraw.Draw(border).rounded_rectangle((0, 0, width + 23, height + 23), 58, fill=(40, 30, 55, 255),
                                             outline=(120, 80, 170, 255), width=3)
    shadow = Image.new('RGBA', (width + 120, height + 120), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((60, 60, width + 60, height + 60), 58, fill=(0, 0, 0, 200))
    image.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(24)), (x - 60, y - 40))
    image.alpha_composite(border, (x - 12, y - 12))
    image.alpha_composite(phone, (x, y))
    image.convert('RGB').save(out, optimize=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--frame', type=Path, help='folder with raw 1080x1920 screenshots (NN-name.png)')
    parser.add_argument('--font-dir', type=Path, default=FONT_DIR)
    args = parser.parse_args()
    STORE.mkdir(exist_ok=True)
    print(icon())
    print(feature_graphic(args.font_dir))
    if args.frame:
        target = STORE / 'screenshots/framed'
        target.mkdir(parents=True, exist_ok=True)
        for shot in sorted(args.frame.glob('*.png')):
            caption = CAPTIONS.get(shot.stem)
            if caption:
                frame(shot, caption, target / shot.name, args.font_dir)
                print(target / shot.name)


if __name__ == '__main__':
    main()
