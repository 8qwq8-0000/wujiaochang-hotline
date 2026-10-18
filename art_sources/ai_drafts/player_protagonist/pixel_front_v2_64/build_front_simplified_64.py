from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parent
SOURCE = ROOT.parent / "pixel_front_v1" / "front_idle_32x32_clean.png"
OUTPUT = ROOT / "front_idle_64x64_simplified.png"

# Collapse the earlier 12-color prototype into seven visual roles. The 64×64
# canvas intentionally uses 2×2 pixel clusters so its contour stays calm and
# readable instead of spending the extra resolution on panel noise.
COLOR_MAP = {
    (59, 70, 80, 255): (37, 44, 52, 255),       # core highlight -> core
    (174, 181, 183, 255): (216, 219, 215, 255), # mid armor -> armor
    (241, 238, 230, 255): (216, 219, 215, 255), # highlight -> armor
    (8, 118, 129, 255): (29, 224, 225, 255),    # cyan shadow -> cyan
    (122, 25, 76, 255): (214, 44, 139, 255),    # magenta shadow -> magenta
}


image = Image.open(SOURCE).convert("RGBA")
pixels = image.load()

for y in range(image.height):
    for x in range(image.width):
        pixels[x, y] = COLOR_MAP.get(pixels[x, y], pixels[x, y])

# Remove the tiny wrist emblem and shin tally. The heavy-arm arrow remains the
# only magenta street-modification mark in this scale prototype.
armor = (216, 219, 215, 255)
core = (37, 44, 52, 255)
for point in ((6, 18), (6, 19)):
    pixels[point] = armor
pixels[20, 25] = core

image = image.resize((64, 64), Image.Resampling.NEAREST)
image.save(OUTPUT)
print(OUTPUT)
