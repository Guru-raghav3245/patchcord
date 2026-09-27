# Draws the app icon (a light-blue take on the macOS icon-grid placeholder).
# Usage (from repo root): python3 scripts/make-icon.py  -> App/Assets.xcassets/AppIcon.appiconset/
from PIL import Image, ImageDraw

S = 4096                      # draw at 4x, downsample for antialiasing
k = S / 1024
img = Image.new("RGBA", (S, S), (0, 0, 0, 0))

# macOS icon body: 824pt square inset 100pt, ~185pt corner radius
x0, y0, x1, y1 = [v * k for v in (100, 100, 924, 924)]
r = 185 * k

d = ImageDraw.Draw(img)
WHITE, BLUE = (255, 255, 255, 255), (28, 66, 140, 255)
d.rounded_rectangle((x0, y0, x1, y1), r, fill=WHITE)
b = 50 * k                    # white frame width
ix0, iy0, ix1, iy1 = x0 + b, y0 + b, x1 - b, y1 - b
d.rounded_rectangle((ix0, iy0, ix1, iy1), r - b, fill=BLUE)

# grid lines, clipped to the inner area
grid = Image.new("RGBA", (S, S), (0, 0, 0, 0))
g = ImageDraw.Draw(grid)
w = round(5 * k)
line = (255, 255, 255, 190)
cx, cy = (ix0 + ix1) / 2, (iy0 + iy1) / 2
h = (ix1 - ix0) / 2
g.line((ix0, iy0, ix1, iy1), line, w)
g.line((ix0, iy1, ix1, iy0), line, w)
for f in (-0.5, 0, 0.5):      # vertical + horizontal lines
    g.line((cx + f * h, iy0, cx + f * h, iy1), line, w)
    g.line((ix0, cy + f * h, ix1, cy + f * h), line, w)
for f in (0.82, 0.5):         # outer and inner circles
    g.ellipse((cx - f * h, cy - f * h, cx + f * h, cy + f * h), outline=line, width=w)
g.rounded_rectangle((cx - 0.7 * h, cy - 0.7 * h, cx + 0.7 * h, cy + 0.7 * h), 0.25 * h, outline=line, width=w)

mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).rounded_rectangle((ix0, iy0, ix1, iy1), r - b, fill=255)
img.alpha_composite(Image.composite(grid, Image.new("RGBA", (S, S)), mask))

# macOS asset catalogs ignore a lone 1024 image; emit the classic 16…512 @1x/@2x set
import json
src = img.resize((1024, 1024), Image.LANCZOS)
images = []
for pt in (16, 32, 128, 256, 512):
    for scale in (1, 2):
        name = f"icon_{pt}x{pt}{'@2x' if scale == 2 else ''}.png"
        src.resize((pt * scale,) * 2, Image.LANCZOS).save(f"App/Assets.xcassets/AppIcon.appiconset/{name}")
        images.append({"filename": name, "idiom": "mac", "scale": f"{scale}x", "size": f"{pt}x{pt}"})
with open("App/Assets.xcassets/AppIcon.appiconset/Contents.json", "w") as f:
    json.dump({"images": images, "info": {"author": "xcode", "version": 1}}, f, indent=2)
