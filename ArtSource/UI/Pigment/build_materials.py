"""Rebuild E/F UI textures from the generated pigment source. Requires Pillow/numpy."""
from pathlib import Path
import re
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "Game/art/ui/pigment"
TOKENS = (ROOT / "Game/ui/ui_tokens.gd").read_text(encoding="utf-8")
COLORS = {key: np.array([int(value[i:i+2], 16) for i in (0, 2, 4)], dtype=float)
          for key, value in re.findall(r'const (\w+) := Color\("([0-9a-f]{6})"\)', TOKENS)}
SCALE = 8
SIZE = 256
PERIOD = SIZE - 40


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    source = Image.open(Path(__file__).with_name("pigment-source.png")).convert("RGB")
    w, h = source.size
    # Opaque central square only: generated outer alpha is never a UI silhouette.
    crop = source.crop((w*.25, h*.25, w*.75, h*.75)).convert("L").resize((PERIOD//2, PERIOD//2), Image.Resampling.LANCZOS)
    a = np.asarray(crop, dtype=float)
    tile = np.concatenate((a, a[:, ::-1]), axis=1)
    tile = np.concatenate((tile, tile[::-1]), axis=0)
    assert np.array_equal(tile[0], tile[-1]) and np.array_equal(tile[:, 0], tile[:, -1])
    tile = (tile - tile.mean()) / max(tile.std(), 1)
    # Current runtime uses this continuous field, not the historical 9-patches.
    neutral = np.uint8(np.clip(250 + tile*2.5, 0, 255))
    Image.fromarray(neutral).convert("RGBA").save(OUT / "wash-tile.png")
    # Fixed 20 px corners; the center is exactly one pigment period.
    y, x = np.mgrid[:SIZE*SCALE, :SIZE*SCALE].astype(float)
    x = (x+.5)/SCALE
    y = (y+.5)/SCALE
    sampled = Image.fromarray(np.uint8(np.clip(tile*28+128, 0, 255))).resize((PERIOD*SCALE, PERIOD*SCALE), Image.Resampling.BILINEAR)
    pigment = (np.asarray(sampled, dtype=float)-128)/28
    tone = pigment[((y-20)*SCALE).astype(int) % (PERIOD*SCALE), ((x-20)*SCALE).astype(int) % (PERIOD*SCALE)]
    qx, qy = np.abs(x-SIZE/2)-(SIZE/2-16), np.abs(y-SIZE/2)-(SIZE/2-16)
    distance = np.sqrt(np.maximum(qx, 0)**2+np.maximum(qy, 0)**2) + np.minimum(np.maximum(qx, qy), 0)-13
    alpha = np.clip(.5-distance*SCALE, 0, 1)
    for name, color, intensity, border in [
        ("panel", "PAPER", 1.4, .9), ("normal", "WASH", 3.5, .8),
        ("hover", "WASH_HOVER", 4.4, 1.1), ("pressed", "WASH_PRESSED", 4.8, 1.1),
        ("disabled", "DISABLED", 1.5, .55)]:
        rgb = np.clip(COLORS[color]+tone[..., None]*intensity, 0, 255)
        # Wash pooling is internal; exact antialiased outer geometry stays stable.
        pooling = np.clip(1+(distance+2.8)/2.8, 0, 1)*.11
        rgb = rgb*(1-pooling[..., None])+COLORS["LEAF"]*pooling[..., None]
        line = np.clip((distance+border)*SCALE+.5, 0, 1)*.72
        rgb = rgb*(1-line[..., None])+(COLORS["EDGE"]+tone[..., None]*3)*line[..., None]
        if name == "pressed":
            accent = (y > SIZE-4.3) & (distance < -.2)
            rgb[accent] = COLORS["ACCENT"]
        rgba = np.dstack((rgb, alpha*255)).astype(np.uint8)
        image = Image.fromarray(rgba).resize((SIZE, SIZE), Image.Resampling.LANCZOS)
        image.save(OUT / f"{name}.png")
    # Small round matte thumb, not the engine default glossy control.
    d = np.sqrt((x-SIZE/2)**2+(y-SIZE/2)**2)-SIZE*.38
    thumb_alpha = np.clip(.5-d*SCALE, 0, 1)
    thumb_rgb = COLORS["PAPER"]+tone[..., None]*2
    edge = np.clip((d+3)*SCALE+.5, 0, 1)*.7
    thumb_rgb = thumb_rgb*(1-edge[..., None])+COLORS["EDGE"]*edge[..., None]
    Image.fromarray(np.uint8(np.clip(np.dstack((thumb_rgb,thumb_alpha*255)),0,255))).resize((24,24),Image.Resampling.LANCZOS).save(OUT / "slider-thumb.png")
    sheet = Image.open(Path(__file__).with_name("icons-source.png")).convert("RGBA")
    for index, name in enumerate(("basket", "sun", "moon")):
        cell = sheet.crop((index*sheet.width//3, 0, (index+1)*sheet.width//3, sheet.height))
        pixels = np.asarray(cell).copy()
        # Discard alpha<8/255 export dust only, never chroma-key painted details.
        pixels[:, :, 3] = np.clip((pixels[:, :, 3].astype(float)-8)*255/247, 0, 255)
        cell = Image.fromarray(pixels)
        bounds = cell.getchannel("A").getbbox()
        if not bounds:
            raise ValueError(f"Empty generated icon: {name}")
        cell = cell.crop(bounds)
        cell.thumbnail((112, 112), Image.Resampling.LANCZOS)
        result = Image.new("RGBA", (128,128))
        result.alpha_composite(cell, ((128-cell.width)//2, (128-cell.height)//2))
        result.save(OUT / f"{name}.png")
    print(f"Built pigment materials/icons in {OUT}; fixed corners=20, tile period={PERIOD}")


if __name__ == "__main__":
    main()
