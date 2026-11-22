#!/usr/bin/env python3
"""Generates the PANDA AI STUDIO monochrome launcher / launch-screen icons.

Pure stdlib (zlib + struct) — no Pillow/numpy needed. Renders with 2x
supersampling, then box-downscales for anti-aliasing.

Design (strictly black #000000 / white #FFFFFF):
  * App icon: full-bleed black square, white panda face (ears + head),
    black eyes.
  * Android legacy mipmap: black rounded square on transparent, same face.
  * Launch image: black panda mark on transparent (for the white iOS
    launch storyboard background).

Regenerate:  python3 tool/generate_icons.py
"""
import os
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

BLACK = (0, 0, 0, 255)
WHITE = (255, 255, 255, 255)
CLEAR = (0, 0, 0, 0)


def _write_png(path, size, rgba):
    """Writes an RGBA PNG. `rgba` is a bytearray of size*size*4."""
    raw = b''.join(
        b'\x00' + bytes(rgba[y * size * 4:(y + 1) * size * 4])
        for y in range(size)
    )

    def chunk(tag, data):
        c = struct.pack('>I', len(data)) + tag + data
        return c + struct.pack('>I', zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = (
        b'\x89PNG\r\n\x1a\n'
        + chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 6, 0, 0, 0))
        + chunk(b'IDAT', zlib.compress(raw, 9))
        + chunk(b'IEND', b'')
    )
    with open(path, 'wb') as fh:
        fh.write(png)


class _Canvas:
    """Row-span rasterizer at SS x the output size (RGBA bytearray)."""

    def __init__(self, size, ss=2):
        self.size = size
        self.ss = ss
        self.n = size * ss
        self.buf = bytearray(self.n * self.n * 4)

    def _fill_span(self, y, x0, x1, color):
        if y < 0 or y >= self.n:
            return
        x0 = max(0, int(x0))
        x1 = min(self.n, int(x1) + 1)
        if x0 >= x1:
            return
        start = (y * self.n + x0) * 4
        self.buf[start:(y * self.n + x1) * 4] = bytes(color) * (x1 - x0)

    def circle(self, cx, cy, r, color):
        n = self.n
        cx, cy, r = cx * n, cy * n, r * n
        for y in range(int(cy - r), int(cy + r) + 1):
            dy = y + 0.5 - cy
            if abs(dy) > r:
                continue
            dx = (r * r - dy * dy) ** 0.5
            self._fill_span(y, cx - dx, cx + dx - 1, color)

    def ellipse(self, cx, cy, rx, ry, color):
        n = self.n
        cx, cy, rx, ry = cx * n, cy * n, rx * n, ry * n
        for y in range(int(cy - ry), int(cy + ry) + 1):
            dy = (y + 0.5 - cy) / ry
            if abs(dy) > 1:
                continue
            dx = rx * (1 - dy * dy) ** 0.5
            self._fill_span(y, cx - dx, cx + dx - 1, color)

    def rounded_rect(self, x0, y0, x1, y1, radius, color):
        n = self.n
        x0, y0, x1, y1, radius = (x0 * n, y0 * n, x1 * n, y1 * n, radius * n)
        for y in range(int(y0), int(y1) + 1):
            py = y + 0.5
            if py < y0 + radius:  # top corners
                dy = (y0 + radius) - py
                dx = radius - max(0.0, radius * radius - dy * dy) ** 0.5
                self._fill_span(y, x0 + dx, x1 - dx - 1, color)
            elif py > y1 - radius:  # bottom corners
                dy = py - (y1 - radius)
                dx = radius - max(0.0, radius * radius - dy * dy) ** 0.5
                self._fill_span(y, x0 + dx, x1 - dx - 1, color)
            else:
                self._fill_span(y, x0, x1 - 1, color)

    def rect(self, x0, y0, x1, y1, color):
        n = self.n
        for y in range(int(y0 * n), int(y1 * n)):
            self._fill_span(y, x0 * n, x1 * n - 1, color)

    def downscale(self):
        ss = self.ss
        out = bytearray(self.size * self.size * 4)
        n, size = self.n, self.size
        buf = self.buf
        area = ss * ss
        for y in range(size):
            for x in range(size):
                r = g = b = a = 0
                for sy in range(y * ss, (y + 1) * ss):
                    base = (sy * n + x * ss) * 4
                    for sx in range(ss):
                        i = base + sx * 4
                        r += buf[i]
                        g += buf[i + 1]
                        b += buf[i + 2]
                        a += buf[i + 3]
                o = (y * size + x) * 4
                out[o] = r // area
                out[o + 1] = g // area
                out[o + 2] = b // area
                out[o + 3] = a // area
        return out


def _draw_face(canvas, ink=WHITE, face=BLACK):
    """Panda face inside the icon. Coordinates match the adaptive-icon
    vector (108dp viewport, normalized 0..1)."""
    # Ears
    canvas.circle(0.278, 0.352, 0.074, ink)
    canvas.circle(0.722, 0.352, 0.074, ink)
    # Head
    canvas.ellipse(0.5, 0.574, 0.204, 0.185, ink)
    # Eyes
    canvas.circle(0.389, 0.556, 0.032, face)
    canvas.circle(0.611, 0.556, 0.032, face)
    # Nose
    canvas.ellipse(0.5, 0.648, 0.030, 0.020, face)


def render_app_icon(size, rounded):
    c = _Canvas(size)
    if rounded:  # Android legacy mipmap: rounded square on transparent
        c.rounded_rect(0.13, 0.13, 0.87, 0.87, 0.13, BLACK)
    else:  # iOS: full-bleed black (Xcode applies the mask)
        c.rect(0.0, 0.0, 1.0, 1.0, BLACK)
    _draw_face(c, ink=WHITE, face=BLACK)
    return c.downscale()


def render_launch_image(size):
    c = _Canvas(size)
    _draw_face(c, ink=BLACK, face=WHITE)
    return c.downscale()


def main():
    # ---- iOS app icon (single-size, Xcode 14+) ----
    icon_dir = os.path.join(
        ROOT, 'ios/Runner/Assets.xcassets/AppIcon.appiconset')
    os.makedirs(icon_dir, exist_ok=True)
    _write_png(os.path.join(icon_dir, 'Icon-App-1024x1024@1x.png'),
               1024, render_app_icon(1024, rounded=False))
    with open(os.path.join(icon_dir, 'Contents.json'), 'w') as fh:
        fh.write('''{
  "images" : [
    {
      "filename" : "Icon-App-1024x1024@1x.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
''')
    print('iOS app icon written')

    # ---- iOS launch images (black mark on transparent, 168pt base) ----
    launch_dir = os.path.join(
        ROOT, 'ios/Runner/Assets.xcassets/LaunchImage.imageset')
    os.makedirs(launch_dir, exist_ok=True)
    for scale, name in ((1, 'LaunchImage.png'), (2, 'LaunchImage@2x.png'),
                        (3, 'LaunchImage@3x.png')):
        _write_png(os.path.join(launch_dir, name),
                   168 * scale, render_launch_image(168 * scale))
    with open(os.path.join(launch_dir, 'Contents.json'), 'w') as fh:
        fh.write('''{
  "images" : [
    {
      "idiom" : "universal",
      "filename" : "LaunchImage.png",
      "scale" : "1x"
    },
    {
      "idiom" : "universal",
      "filename" : "LaunchImage@2x.png",
      "scale" : "2x"
    },
    {
      "idiom" : "universal",
      "filename" : "LaunchImage@3x.png",
      "scale" : "3x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
''')
    print('iOS launch images written')

    # ---- Android legacy mipmaps (pre-API 26 fallbacks) ----
    for dpi, px in (('mdpi', 48), ('hdpi', 72), ('xhdpi', 96),
                    ('xxhdpi', 144), ('xxxhdpi', 192)):
        mipmap = os.path.join(
            ROOT, 'android/app/src/main/res/mipmap-%s' % dpi)
        os.makedirs(mipmap, exist_ok=True)
        _write_png(os.path.join(mipmap, 'ic_launcher.png'),
                   px, render_app_icon(px, rounded=True))
    print('Android mipmaps written')


if __name__ == '__main__':
    main()
