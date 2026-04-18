"""
Wrap raw Android screenshots in a phone mockup (Craftelle style) with a
bold white caption ABOVE the phone. Handles two modes:

1) Raw run: any .jpg/.png/.jpeg that isn't deeks-N.png → frame, caption,
   rename sequentially to deeks-1.png ... deeks-N.png, delete originals.

2) Re-caption run (no raw files present): take existing deeks-N.png and
   add a fresh caption strip on top (does NOT re-frame).

Captions live in the CAPTIONS dict, keyed by the 1-based index.
"""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

# --- captions per output index ---------------------------------------------
CAPTIONS = {
    1: "Save Meeting Links",
    2: "Save Links",
    3: "Encrypted Vault",
    4: "Capture Notes",
    5: "Secure Login",
    6: "Create Account",
}
FALLBACK_CAPTION = "Deeks"

# --- tunables ---------------------------------------------------------------
BEZEL = 28
CORNER = 64
SCREEN_CORNER = 40
CAMERA_RADIUS = 7
SIDE_BUTTON_W = 6
BG_COLOR = (11, 30, 63, 255)       # dark navy
BEZEL_COLOR = (12, 12, 14, 255)
CAPTION_COLOR = (255, 255, 255, 255)
CAPTION_SIZE = 92
CAPTION_TOP_PAD = 70
CAPTION_BOTTOM_PAD = 60
PADDING_X = 80
PADDING_BOTTOM = 80


def rounded_rect_mask(size, radius):
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)
    return mask


def load_font(size: int) -> ImageFont.ImageFont:
    for path in (r"C:\Windows\Fonts\segoeuib.ttf", r"C:\Windows\Fonts\arialbd.ttf",
                 r"C:\Windows\Fonts\calibrib.ttf", r"C:\Windows\Fonts\seguibl.ttf"):
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()


def measure_text(text: str, font):
    tmp = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
    bbox = tmp.textbbox((0, 0), text, font=font)
    return bbox, bbox[2] - bbox[0], bbox[3] - bbox[1]


def draw_caption(img: Image.Image, caption: str) -> Image.Image:
    """Extend img upward with a caption band and draw caption text."""
    font = load_font(CAPTION_SIZE)
    bbox, text_w, text_h = measure_text(caption, font)
    band_h = CAPTION_TOP_PAD + text_h + CAPTION_BOTTOM_PAD

    w, h = img.size
    new_w = max(w, text_w + PADDING_X * 2)
    canvas = Image.new("RGBA", (new_w, band_h + h), BG_COLOR)

    d = ImageDraw.Draw(canvas)
    tx = (new_w - text_w) // 2 - bbox[0]
    ty = CAPTION_TOP_PAD - bbox[1]
    d.text((tx, ty), caption, font=font, fill=CAPTION_COLOR)

    paste_x = (new_w - w) // 2
    canvas.paste(img.convert("RGBA"), (paste_x, band_h))
    return canvas


def build_phone(screen_img: Image.Image) -> Image.Image:
    sw, sh = screen_img.size
    phone_w = sw + BEZEL * 2
    phone_h = sh + BEZEL * 2

    phone = Image.new("RGBA", (phone_w, phone_h), BEZEL_COLOR)
    phone.putalpha(rounded_rect_mask((phone_w, phone_h), CORNER))

    screen_mask = rounded_rect_mask((sw, sh), SCREEN_CORNER)
    phone.paste(screen_img, (BEZEL, BEZEL), screen_mask)

    d = ImageDraw.Draw(phone)
    cx = phone_w // 2
    cy = BEZEL + CAMERA_RADIUS + 14
    d.ellipse((cx - CAMERA_RADIUS, cy - CAMERA_RADIUS, cx + CAMERA_RADIUS, cy + CAMERA_RADIUS),
              fill=(4, 4, 6, 255))

    right_x = phone_w - SIDE_BUTTON_W + 2
    d.rectangle((right_x - 2, int(phone_h * 0.22), right_x + 6, int(phone_h * 0.27)), fill=(20, 20, 22, 255))
    d.rectangle((right_x - 2, int(phone_h * 0.30), right_x + 6, int(phone_h * 0.38)), fill=(20, 20, 22, 255))
    d.rectangle((-6, int(phone_h * 0.26), 2, int(phone_h * 0.31)), fill=(20, 20, 22, 255))
    d.rectangle((-6, int(phone_h * 0.34), 2, int(phone_h * 0.39)), fill=(20, 20, 22, 255))
    return phone


def frame_and_caption_raw(src: Path, dest: Path, caption: str) -> None:
    screen = Image.open(src).convert("RGB")
    phone = build_phone(screen)
    pw, ph = phone.size

    canvas_w = pw + PADDING_X * 2
    canvas_h = ph + PADDING_BOTTOM + PADDING_X
    canvas = Image.new("RGBA", (canvas_w, canvas_h), BG_COLOR)

    shadow = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shadow)
    sdraw.rounded_rectangle((PADDING_X + 8, PADDING_X + 28,
                             PADDING_X + pw + 8, PADDING_X + ph + 28),
                            radius=CORNER, fill=(0, 0, 0, 130))
    shadow = shadow.filter(ImageFilter.GaussianBlur(22))
    canvas.alpha_composite(shadow)
    canvas.alpha_composite(phone, (PADDING_X, PADDING_X))

    captioned = draw_caption(canvas, caption)
    captioned.convert("RGB").save(dest, "PNG", optimize=True)


def recaption_existing(path: Path, caption: str) -> None:
    """Strip any existing caption band, then apply a fresh caption on top."""
    img = Image.open(path).convert("RGB")
    w, h = img.size
    # Find the phone bezel: the first row where a pixel in the central band
    # is very dark (sum(RGB) < 60 — bezel is ~(12,12,14); navy BG is (11,30,63)
    # which sums to 104 so we won't false-match the background).
    phone_top = None
    x_start = w // 4
    x_end = 3 * w // 4
    step = max(1, (x_end - x_start) // 40)
    for y in range(h):
        for x in range(x_start, x_end, step):
            r, g, b = img.getpixel((x, y))
            if r + g + b < 60:
                phone_top = y
                break
        if phone_top is not None:
            break
    if phone_top is None or phone_top < 50:
        phone_top = 260  # fallback

    # Also strip the small padding gap above the phone so draw_caption can
    # re-introduce its own uniform top padding.
    cropped = img.crop((0, phone_top, w, h))
    captioned = draw_caption(cropped, caption)
    captioned.convert("RGB").save(path, "PNG", optimize=True)


def main():
    folder = Path(__file__).parent
    exts = {".png", ".jpg", ".jpeg"}

    raw = sorted(
        p for p in folder.iterdir()
        if p.suffix.lower() in exts and not p.stem.startswith("deeks-")
    )
    existing = sorted(
        p for p in folder.iterdir()
        if p.suffix.lower() == ".png" and p.stem.startswith("deeks-")
    )

    if raw:
        for i, src in enumerate(raw, start=1):
            dest = folder / f"deeks-{i}.png"
            caption = CAPTIONS.get(i, FALLBACK_CAPTION)
            temp = folder / f".pending-deeks-{i}.png"
            print(f"{src.name} -> {dest.name}  [{caption}]")
            frame_and_caption_raw(src, temp, caption)
            if dest.exists():
                dest.unlink()
            temp.rename(dest)
            src.unlink()
        return

    if existing:
        print("Re-captioning existing deeks-N.png files in place.")
        for i, src in enumerate(existing, start=1):
            caption = CAPTIONS.get(i, FALLBACK_CAPTION)
            print(f"{src.name}  [{caption}]")
            recaption_existing(src, caption)
        return

    print("No screenshots found.")


if __name__ == "__main__":
    main()
