# Draws the app icon (DESIGN.md "Icon"): graphite squircle, one cable looping out and back into a USB-C plug,
# amber indicator LED. Coordinates are in the 512-unit space of the design preview's SVG.
# Usage (from repo root): python3 scripts/make-icon.py
#   -> App/Assets.xcassets/AppIcon.appiconset/ (16…512 @1x/@2x), site/icon.png (512), site/favicon.png (64)
import json
from PIL import Image, ImageDraw, ImageFilter

S = 4096                                  # draw at 4x of 1024, downsample for antialiasing
F = 824 / 448 * S / 1024                  # SVG body 32..480 -> macOS icon body 100..924 (of 1024)
def p(x, y): return (100 * S / 1024 + (x - 32) * F, 100 * S / 1024 + (y - 32) * F)
def s(v): return v * F

BONE, TIP, AMBER, HOT = (232, 230, 225, 255), (185, 182, 174, 255), (242, 163, 58, 255), (255, 233, 196, 255)
img = Image.new("RGBA", (S, S), (0, 0, 0, 0))

# body: vertical graphite gradient, clipped to the squircle, with a faint brushed grain and a dark rim
body = Image.new("RGBA", (S, S))
stops = [(0, (52, 55, 60)), (0.55, (28, 30, 34)), (1, (18, 19, 22))]
x0, y0 = p(32, 32); x1, y1 = p(480, 480)
bd = ImageDraw.Draw(body)
for y in range(int(y0), int(y1) + 1):
    t = (y - y0) / (y1 - y0)
    (ta, ca), (tb, cb) = next((stops[i], stops[i + 1]) for i in range(len(stops) - 1) if t <= stops[i + 1][0])
    u = (t - ta) / (tb - ta)
    bd.line((x0, y, x1, y), tuple(round(a + (b - a) * u) for a, b in zip(ca, cb)) + (255,))
grain = Image.new("RGBA", (S, S), (0, 0, 0, 0))   # brushed grain: light and dark hairlines, blended on top
gd = ImageDraw.Draw(grain)
x = x0
while x < x1:
    gd.line((x, y0, x, y1), (255, 255, 255, 9), max(1, round(s(1))))
    gd.line((x + s(3), y0, x + s(3), y1), (0, 0, 0, 15), max(1, round(s(1))))
    x += s(6)
body.alpha_composite(grain)
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).rounded_rectangle((x0, y0, x1, y1), s(100), fill=255)
rim = Image.new("L", (S, S), 0)
ImageDraw.Draw(rim).rounded_rectangle((*p(28, 28), *p(484, 484)), s(104), fill=255)
img.paste((10, 11, 12, 255), (0, 0), rim)
img.paste(body, (0, 0), mask)
hl = Image.new("RGBA", (S, S), (0, 0, 0, 0))   # thin top highlight on the rim
ImageDraw.Draw(hl).rounded_rectangle((x0, y0, x1, y1), s(100), outline=(255, 255, 255, 40), width=round(s(2)))
img.alpha_composite(Image.composite(hl, Image.new("RGBA", (S, S)), mask))

# cable: top run right into an arrowhead, loop back along the bottom into the plug.
# Drawn 1.15x about its centre (and centred vertically) so it fills the squircle like system icons do.
K = 1.15
def g(x, y): return p(260 + (x - 260) * K, 246 + (y - 236) * K)
d = ImageDraw.Draw(img)
w = round(s(30 * K))
def stroke(points):                      # stamp round dots along the path: smooth joins and round caps
    pts = [g(*q) for q in points]
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        n = max(1, int(((bx - ax) ** 2 + (by - ay) ** 2) ** .5 / 4))
        for i in range(n + 1):
            x, y = ax + (bx - ax) * i / n, ay + (by - ay) * i / n
            d.ellipse((x - w / 2, y - w / 2, x + w / 2, y + w / 2), BONE)
def cubic(a, b, c, e, n=48):
    return [tuple((1 - t) ** 3 * a[i] + 3 * (1 - t) ** 2 * t * b[i] + 3 * (1 - t) * t * t * c[i] + t ** 3 * e[i]
                  for i in (0, 1)) for t in (k / n for k in range(n + 1))]
stroke([(150, 206), (352, 206)])
stroke([(316, 166), (360, 206), (316, 246)])
stroke(cubic((150, 206), (96, 206), (96, 306), (150, 306)) + [(330, 306)])
d.rounded_rectangle((*g(326, 280), *g(404, 332)), s(26 * K), fill=BONE)
d.rounded_rectangle((*g(404, 294), *g(426, 318)), s(8 * K), fill=TIP)

# amber LED with a soft glow
glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
cx, cy = p(400, 112)
ImageDraw.Draw(glow).ellipse((cx - s(30), cy - s(30), cx + s(30), cy + s(30)), (242, 163, 58, 150))
img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(s(14))))
d.ellipse((cx - s(15), cy - s(15), cx + s(15), cy + s(15)), AMBER)
hx, hy = p(396, 108)
d.ellipse((hx - s(5), hy - s(5), hx + s(5), hy + s(5)), HOT)

# macOS asset catalogs ignore a lone 1024 image; emit the classic 16…512 @1x/@2x set
src = img.resize((1024, 1024), Image.LANCZOS)
out = "App/Assets.xcassets/AppIcon.appiconset"
images = []
for pt in (16, 32, 128, 256, 512):
    for scale in (1, 2):
        name = f"icon_{pt}x{pt}{'@2x' if scale == 2 else ''}.png"
        src.resize((pt * scale,) * 2, Image.LANCZOS).save(f"{out}/{name}")
        images.append({"filename": name, "idiom": "mac", "scale": f"{scale}x", "size": f"{pt}x{pt}"})
with open(f"{out}/Contents.json", "w") as f:
    json.dump({"images": images, "info": {"author": "xcode", "version": 1}}, f, indent=2)
src.resize((512, 512), Image.LANCZOS).save("site/icon.png")
src.resize((64, 64), Image.LANCZOS).save("site/favicon.png")
