#!/usr/bin/env python3
"""Micro-assembler cho vi chương trình dọc của tlc_vmicro.

Cách dùng:  python sw/uasm.py sw/traffic.uasm rtl/vmicrocode.mem
Cú pháp giống sw/asm.py (nhãn, .equ, chú thích ';'). Vi lệnh:
    LIGHT giá_trị          TIMER số_tick
    BR    điều_kiện, nhãn   CLR   mặt_nạ
Điều kiện: ALWAYS TRUN NIGHT NNIGHT SN NSN SENSOR PED
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from asm import AsmError, eval_expr, parse_lines  # noqa: E402

DEPTH, ADDR_BITS = 64, 6
OPS = {"LIGHT": 0b00, "TIMER": 0b01, "BR": 0b10, "CLR": 0b11}
CONDS = {"ALWAYS": 0, "TRUN": 1, "NIGHT": 2, "NNIGHT": 3,
         "SN": 4, "NSN": 5, "SENSOR": 6, "PED": 7}


def assemble(src):
    lines = parse_lines(src)
    symbols, upc = {}, 0
    for n, label, mnem, ops, _ in lines:
        if mnem == ".EQU":
            symbols[ops[0]] = eval_expr(ops[1], symbols)
            continue
        if label:
            symbols[label] = upc
        if mnem:
            if mnem not in OPS:
                raise AsmError(f"dòng {n}: vi lệnh không biết: {mnem}")
            upc += 1
    if upc > DEPTH:
        raise AsmError(f"vi chương trình dài {upc} từ, vượt control store {DEPTH} từ")

    words, listing = [], []
    for n, label, mnem, ops, raw in lines:
        if mnem in (None, ".EQU"):
            continue
        try:
            if mnem == "BR":
                if len(ops) != 2 or ops[0].upper() not in CONDS:
                    raise AsmError("BR cần: điều_kiện, địa_chỉ")
                target = eval_expr(ops[1], symbols)
                if not 0 <= target < DEPTH:
                    raise AsmError(f"địa chỉ ngoài control store: {target}")
                arg = (CONDS[ops[0].upper()] << ADDR_BITS) | target
            else:
                if len(ops) != 1:
                    raise AsmError(f"{mnem} cần 1 toán hạng")
                arg = eval_expr(ops[0], symbols)
                if not 0 <= arg <= 0x1FF:
                    raise AsmError(f"toán hạng ngoài phạm vi 9 bit: {arg}")
        except AsmError as e:
            raise AsmError(f"dòng {n}: {e}") from None
        word = (OPS[mnem] << 9) | arg
        listing.append(f"   {word >> 9:02b}_{word & 0x1FF:09b}   // {len(words):2d}  {raw.strip()}")
        words.append(word)
    return words, listing


def main(argv):
    for stream in (sys.stdout, sys.stderr):
        stream.reconfigure(encoding="utf-8")
    if len(argv) != 3:
        print(__doc__)
        return 1
    src = Path(argv[1]).read_text(encoding="utf-8")
    try:
        words, listing = assemble(src)
    except AsmError as e:
        print(f"{argv[1]}: lỗi: {e}", file=sys.stderr)
        return 1
    fill = (OPS["BR"] << 9) | 0  # ô trống: BR ALWAYS, 0
    body = listing + [f"   {fill >> 9:02b}_{fill & 0x1FF:09b}   // {i:2d}  (trống) BR ALWAYS, 0"
                      for i in range(len(words), DEPTH)]
    header = f"// Sinh tự động từ {Path(argv[1]).name} bởi sw/uasm.py - không sửa tay\n"
    Path(argv[2]).write_text(header + "\n".join(body) + "\n", encoding="utf-8")
    print(f"{argv[1]}: {len(words)}/{DEPTH} vi lệnh -> {argv[2]}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
