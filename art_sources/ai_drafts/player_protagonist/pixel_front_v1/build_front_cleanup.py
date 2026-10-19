from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parent
OUT = ROOT / "front_idle_32x32_clean.png"

P = {
    "outline": "#12161C",
    "core": "#252C34",
    "core_hi": "#3B4650",
    "armor_dark": "#717A80",
    "armor_mid": "#AEB5B7",
    "armor": "#D8DBD7",
    "armor_hi": "#F1EEE6",
    "municipal": "#70899A",
    "cyan_dark": "#087681",
    "cyan": "#1DE0E1",
    "magenta_dark": "#7A194C",
    "magenta": "#D62C8B",
}


def poly(draw: ImageDraw.ImageDraw, points, color: str) -> None:
    draw.polygon(points, fill=P[color])


def rect(draw: ImageDraw.ImageDraw, box, color: str) -> None:
    draw.rectangle(box, fill=P[color])


im = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
d = ImageDraw.Draw(im)

# Back silhouette: compact 3.5-head contractor body, feet ending on y=28.
poly(d, [(13, 2), (18, 2), (20, 4), (21, 9), (20, 11), (22, 11),
         (23, 9), (27, 10), (29, 14), (28, 22), (25, 24), (23, 22),
         (22, 27), (21, 28), (17, 28), (16, 27), (15, 28), (10, 28),
         (9, 27), (9, 23), (6, 24), (3, 22), (4, 13), (7, 10), (10, 10),
         (11, 8), (11, 4)], "outline")

# Helmet shell and faceplate.
poly(d, [(13, 3), (18, 3), (19, 5), (20, 8), (18, 10), (13, 10),
         (11, 8), (12, 5)], "core_hi")
poly(d, [(14, 3), (17, 3), (18, 5), (13, 5)], "armor_dark")
poly(d, [(13, 5), (18, 5), (19, 8), (17, 10), (14, 10), (12, 8)], "armor")
rect(d, (14, 5, 17, 5), "armor_hi")
rect(d, (13, 7, 18, 8), "outline")
rect(d, (14, 7, 17, 7), "cyan")
rect(d, (15, 8, 16, 8), "cyan_dark")

# Neck and dark undersuit core.
poly(d, [(12, 9), (19, 9), (22, 13), (21, 20), (18, 22), (13, 22),
         (10, 20), (9, 13)], "core")
rect(d, (14, 10, 17, 11), "core_hi")

# Image-left: anatomical-right light work arm and shoulder.
poly(d, [(7, 10), (10, 10), (12, 12), (10, 16), (9, 21), (6, 22),
         (4, 20), (5, 13)], "armor_dark")
poly(d, [(7, 11), (10, 11), (11, 13), (9, 15), (6, 14)], "armor")
rect(d, (6, 12, 8, 12), "armor_hi")
poly(d, [(6, 15), (9, 15), (9, 20), (7, 21), (5, 19)], "armor")
rect(d, (5, 17, 6, 19), "municipal")
rect(d, (6, 18, 6, 19), "magenta")
rect(d, (7, 21, 9, 22), "core_hi")
rect(d, (6, 22, 8, 23), "armor_mid")
rect(d, (5, 22, 5, 22), "armor_hi")

# Image-right: anatomical-left heavy integrated guard arm.
poly(d, [(21, 10), (25, 9), (28, 12), (29, 19), (27, 23), (23, 23),
         (21, 20), (22, 16), (20, 13)], "armor_dark")
poly(d, [(23, 10), (25, 10), (27, 12), (26, 15), (22, 14), (21, 12)], "armor_mid")
rect(d, (23, 11, 25, 12), "municipal")
poly(d, [(23, 14), (27, 14), (28, 18), (27, 22), (23, 22), (22, 19)], "core_hi")
rect(d, (26, 15, 27, 20), "magenta_dark")
rect(d, (25, 17, 27, 18), "magenta")
rect(d, (24, 16, 26, 17), "magenta")
rect(d, (25, 15, 26, 15), "magenta")
rect(d, (24, 19, 25, 21), "magenta")
rect(d, (23, 21, 25, 21), "magenta")
rect(d, (25, 22, 27, 23), "armor_mid")

# Chest plates and AI communication spine.
poly(d, [(10, 12), (14, 11), (15, 13), (14, 18), (11, 18), (9, 15)], "armor")
poly(d, [(17, 11), (21, 12), (22, 15), (20, 18), (17, 18), (16, 13)], "armor")
rect(d, (11, 12, 12, 12), "armor_hi")
rect(d, (19, 12, 20, 12), "municipal")
rect(d, (15, 11, 16, 12), "cyan_dark")
rect(d, (15, 13, 16, 16), "cyan")
rect(d, (15, 17, 16, 18), "cyan_dark")
poly(d, [(11, 18), (14, 18), (15, 20), (13, 22), (10, 20)], "armor_dark")
poly(d, [(17, 18), (20, 18), (21, 20), (18, 22), (16, 20)], "armor_dark")
rect(d, (14, 20, 17, 21), "core_hi")

# Two separated mechanical legs.
poly(d, [(10, 21), (14, 21), (15, 24), (14, 27), (13, 28), (10, 28),
         (9, 26)], "armor_mid")
poly(d, [(17, 21), (21, 21), (23, 25), (21, 28), (18, 28), (17, 27),
         (16, 24)], "armor_mid")
rect(d, (11, 22, 13, 24), "armor")
rect(d, (18, 22, 20, 24), "armor")
rect(d, (10, 25, 13, 26), "municipal")
rect(d, (19, 25, 21, 26), "core_hi")
rect(d, (14, 22, 14, 26), "core")
rect(d, (16, 22, 17, 27), "outline")

# Wide split-toe boots and one small extraction tally cadence.
poly(d, [(9, 26), (13, 26), (14, 28), (12, 28), (11, 27), (10, 28), (8, 28)], "outline")
poly(d, [(18, 26), (22, 26), (23, 28), (21, 28), (20, 27), (19, 28), (17, 28)], "outline")
rect(d, (9, 27, 10, 27), "armor_hi")
rect(d, (12, 27, 13, 27), "armor")
rect(d, (18, 27, 19, 27), "armor")
rect(d, (21, 27, 22, 27), "armor_hi")
rect(d, (20, 25, 20, 25), "magenta")

im.save(OUT)
print(OUT)
