"""Vẽ ảnh mã nguồn kiểu CodeSnap (khung cửa sổ, tô màu cú pháp, số dòng thật).

    python scripts/codesnap.py <file> <tên_ảnh> [<dòng_đầu>-<dòng_cuối> ...]

Mỗi khoảng dòng sinh một ảnh <tên_ảnh>_<k>.png trong thư mục Images của báo cáo
LaTeX (đổi bằng biến môi trường SNAP_OUT). Đúng một khoảng dòng thì ảnh tên
<tên_ảnh>.png. Không ghi khoảng dòng thì cả file được cắt tự động tại dòng trống.
SNAP_TITLE đổi tiêu đề trên khung cửa sổ, SNAP_NOLN=1 bỏ số dòng (dùng cho
output terminal).
"""
import os
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont
from pygments import lex
from pygments.lexers import get_lexer_for_filename, NasmLexer, TextLexer, VerilogLexer
from pygments.token import Token

ROOT = Path(__file__).resolve().parent.parent
OUT = Path(os.environ.get(
    "SNAP_OUT", ROOT / "GraduationThesisTemplate-main - Copy" / "GraduationThesisTemplate-main" / "Images"))

S = 2                                   # hệ số phóng để ảnh nét khi in
FONT = ImageFont.truetype("C:/Windows/Fonts/consola.ttf", 15 * S)
FONT_B = ImageFont.truetype("C:/Windows/Fonts/consolab.ttf", 15 * S)
LINE_H = 22 * S
CHAR_W = FONT.getlength("M")

BG_OUTER = (171, 184, 195)              # nền ngoài khung, giống mặc định CodeSnap
BG_WIN = (40, 44, 52)                   # One Dark
FG = (171, 178, 191)
LN = (99, 109, 131)

# màu theo loại token (One Dark)
COLORS = [
    (Token.Comment, (127, 132, 142), False),
    (Token.Keyword.Type, (229, 192, 123), False),
    (Token.Keyword, (198, 120, 221), True),
    (Token.Name.Builtin, (86, 182, 194), False),
    (Token.Name.Function, (97, 175, 239), False),
    (Token.Name.Label, (97, 175, 239), False),
    (Token.Name.Constant, (209, 154, 102), False),
    (Token.Name.Variable, (224, 108, 117), False),
    (Token.Comment.Preproc, (198, 120, 221), False),
    (Token.Literal.String, (152, 195, 121), False),
    (Token.Literal.Number, (209, 154, 102), False),
    (Token.Operator, (86, 182, 194), False),
    (Token.Punctuation, (171, 178, 191), False),
]


def style(tok):
    for t, c, b in COLORS:
        if tok in t:
            return c, b
    return FG, False


def lexer_for(path):
    if path.suffix in (".asm", ".uasm"):
        return NasmLexer()
    if path.suffix == ".vh":
        return VerilogLexer()
    if path.suffix in (".txt", ".mem"):
        return TextLexer()
    return get_lexer_for_filename(path.name)


def auto_ranges(src, max_lines=45):
    """Cắt file thành các đoạn dài gần bằng nhau (<= max_lines dòng), ưu tiên
    cắt tại dòng trống gần điểm chia nhất."""
    lines = src.split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    n = len(lines)
    k = -(-n // max_lines)
    out, start = [], 1
    for j in range(1, k):
        target = round(n * j / k)
        cands = [i for i in range(target - 8, target + 9)
                 if start + 10 <= i < n and i - start + 1 <= max_lines and not lines[i - 1].strip()]
        end = min(cands, key=lambda i: abs(i - target)) if cands else min(target, start + max_lines - 1)
        out.append((start, end))
        start = end + 1
    out.append((start, n))
    return out


def token_lines(src, lexer):
    """Tách luồng token thành từng dòng: [[(token, text), ...], ...]."""
    lines, cur = [], []
    for tok, text in lex(src, lexer):
        parts = text.split("\n")
        for i, p in enumerate(parts):
            if i:
                lines.append(cur)
                cur = []
            if p:
                cur.append((tok, p))
    if cur:
        lines.append(cur)
    return lines


def render(rel, lines, first, last, out):
    rows = lines[first - 1:last]
    no_ln = bool(os.environ.get("SNAP_NOLN"))
    ln_w = 0 if no_ln else len(str(last)) * CHAR_W + 24 * S
    width_chars = max((sum(len(t) for _, t in r) for r in rows), default=0)
    pad_out, pad_in, bar = 32 * S, 20 * S, 40 * S
    win_w = int(ln_w + width_chars * CHAR_W + 2 * pad_in)
    win_w = max(win_w, int(FONT.getlength(rel) + 160 * S))
    win_h = bar + len(rows) * LINE_H + pad_in
    img = Image.new("RGB", (win_w + 2 * pad_out, win_h + 2 * pad_out), BG_OUTER)
    d = ImageDraw.Draw(img)

    x0, y0 = pad_out, pad_out
    d.rounded_rectangle([x0 + 4 * S, y0 + 8 * S, x0 + win_w + 4 * S, y0 + win_h + 8 * S],
                        radius=10 * S, fill=(140, 152, 163))          # bóng đổ
    d.rounded_rectangle([x0, y0, x0 + win_w, y0 + win_h], radius=10 * S, fill=BG_WIN)
    for i, c in enumerate([(255, 95, 86), (255, 189, 46), (39, 201, 63)]):
        cx, cy, r = x0 + (20 + 22 * i) * S, y0 + 20 * S, 6 * S
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=c)
    tw = FONT.getlength(rel)
    d.text((x0 + (win_w - tw) / 2, y0 + 10 * S), rel, font=FONT, fill=LN)

    y = y0 + bar
    for n, row in enumerate(rows, start=first):
        num = "" if no_ln else str(n)
        d.text((x0 + pad_in + ln_w - 16 * S - FONT.getlength(num), y), num, font=FONT, fill=LN)
        x = x0 + pad_in + ln_w
        for tok, text in row:
            text = text.replace("\t", "    ")
            c, b = style(tok)
            d.text((x, y), text, font=FONT_B if b else FONT, fill=c)
            x += len(text) * CHAR_W
        y += LINE_H
    img.save(out)
    print(f"{out.name}: dòng {first}-{last}")


def main():
    path = ROOT / sys.argv[1]
    name = sys.argv[2]
    title = os.environ.get("SNAP_TITLE", sys.argv[1])
    src = path.read_text(encoding="utf-8")
    lines = token_lines(src, lexer_for(path))
    OUT.mkdir(parents=True, exist_ok=True)
    if len(sys.argv) > 3:                           # khoảng dòng cho trước
        ranges = [tuple(map(int, r.split("-"))) for r in sys.argv[3:]]
    else:                                           # tự cắt cả file
        ranges = auto_ranges(src)
    single = len(ranges) == 1 and len(sys.argv) == 4
    for k, (a, b) in enumerate(ranges, start=1):
        out = OUT / (f"{name}.png" if single else f"{name}_{k}.png")
        render(title, lines, a, b, out)


if __name__ == "__main__":
    main()
