#!/usr/bin/env python3
"""여러 PNG/JPG 를 한 장으로 붙인다(캐릭터 캡처 검토용).
사용: python3 tools/montage.py <출력.jpg> <열 수> <그림1> <그림2> ...   (각 그림 위에 파일 이름을 적는다)
      --h=360 으로 칸 높이를 바꿀 수 있다(기본 360)."""
import sys, os
from PIL import Image, ImageDraw


def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    opts = dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--") and "=" in a)
    if len(args) < 3:
        print(__doc__)
        sys.exit(1)
    out, cols, files = args[0], int(args[1]), args[2:]
    cell_h = int(opts.get("h", 360))
    tiles = []
    for f in files:
        im = Image.open(f).convert("RGB")
        w = int(im.width * cell_h / im.height)
        tiles.append((os.path.basename(f), im.resize((w, cell_h), Image.LANCZOS)))
    cell_w = max(t[1].width for t in tiles)
    rows = (len(tiles) + cols - 1) // cols
    label_h = 18
    sheet = Image.new("RGB", (cell_w * cols, (cell_h + label_h) * rows), (235, 235, 235))
    draw = ImageDraw.Draw(sheet)
    for i, (name, im) in enumerate(tiles):
        x = (i % cols) * cell_w
        y = (i // cols) * (cell_h + label_h)
        sheet.paste(im, (x + (cell_w - im.width) // 2, y + label_h))
        draw.text((x + 4, y + 2), name, fill=(40, 40, 40))
    sheet.save(out, quality=90)
    print("montage", out, sheet.size)


if __name__ == "__main__":
    main()
