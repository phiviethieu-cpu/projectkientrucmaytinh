#!/usr/bin/env python3
"""Assembler hai lượt cho mini_cpu.

Cách dùng:  python sw/asm.py sw/traffic.asm sw/traffic.hex
Sinh ra file .hex (cho $readmemh, 256 từ 16 bit) và file .lst (listing).

Cú pháp:
    nhãn:   MNEMONIC toán_hạng, toán_hạng   ; chú thích
    .equ    TÊN, biểu_thức
Biểu thức hỗ trợ số (10, 0x1F, 0b101), hằng .equ, nhãn, + - * ( ).
"""
import ast
import operator
import re
import sys

MEM_WORDS = 256
FILL = 0xF000  # ô nhớ trống = HALT

# mnemonic -> (opcode, kiểu toán hạng)
#   ""      không có toán hạng
#   "rd,imm" "rd,rs" "port,rs" "rd,port" "addr"
ISA = {
    "NOP":  (0x0, ""),
    "LDI":  (0x1, "rd,imm"),
    "ADD":  (0x2, "rd,rs"),
    "ADDI": (0x3, "rd,imm"),
    "SUB":  (0x4, "rd,rs"),
    "AND":  (0x5, "rd,rs"),
    "ANDI": (0x6, "rd,imm"),
    "OR":   (0x7, "rd,rs"),
    "IN":   (0x8, "rd,imm"),
    "OUT":  (0x9, "imm,rs"),
    "JMP":  (0xA, "imm"),
    "JZ":   (0xB, "imm"),
    "JNZ":  (0xC, "imm"),
    "CALL": (0xD, "imm"),
    "RET":  (0xE, ""),
    "HALT": (0xF, ""),
}

_BINOPS = {ast.Add: operator.add, ast.Sub: operator.sub, ast.Mult: operator.mul}


class AsmError(Exception):
    pass


def eval_expr(text, symbols):
    """Tính biểu thức số nguyên đơn giản, không dùng eval()."""
    def walk(node):
        if isinstance(node, ast.Expression):
            return walk(node.body)
        if isinstance(node, ast.Constant) and isinstance(node.value, int):
            return node.value
        if isinstance(node, ast.Name):
            if node.id not in symbols:
                raise AsmError(f"ký hiệu chưa định nghĩa: {node.id}")
            return symbols[node.id]
        if isinstance(node, ast.BinOp) and type(node.op) in _BINOPS:
            return _BINOPS[type(node.op)](walk(node.left), walk(node.right))
        if isinstance(node, ast.UnaryOp) and isinstance(node.op, ast.USub):
            return -walk(node.operand)
        raise AsmError(f"biểu thức không hợp lệ: {text}")
    return walk(ast.parse(text.strip(), mode="eval"))


def parse_reg(tok):
    m = re.fullmatch(r"[Rr]([0-3])", tok.strip())
    if not m:
        raise AsmError(f"thanh ghi không hợp lệ: {tok}")
    return int(m.group(1))


def parse_lines(src):
    """Trả về danh sách (số dòng, nhãn, mnemonic, [toán hạng], dòng gốc)."""
    out = []
    for n, raw in enumerate(src.splitlines(), 1):
        line = raw.split(";", 1)[0].strip()
        if not line:
            continue
        label = None
        m = re.match(r"([A-Za-z_]\w*)\s*:\s*(.*)$", line)
        if m:
            label, line = m.group(1), m.group(2).strip()
        mnem, ops = None, []
        if line:
            parts = line.split(None, 1)
            mnem = parts[0].upper()
            if len(parts) > 1:
                ops = [o.strip() for o in parts[1].split(",")]
        out.append((n, label, mnem, ops, raw.rstrip()))
    return out


def assemble(src):
    lines = parse_lines(src)
    symbols, pc = {}, 0

    # Lượt 1: gán địa chỉ nhãn, ghi nhận .equ
    for n, label, mnem, ops, _ in lines:
        try:
            if mnem == ".EQU":
                if len(ops) != 2:
                    raise AsmError(".equ cần 2 toán hạng")
                symbols[ops[0]] = eval_expr(ops[1], symbols)
                continue
            if label:
                if label in symbols:
                    raise AsmError(f"nhãn trùng: {label}")
                symbols[label] = pc
            if mnem:
                if mnem not in ISA:
                    raise AsmError(f"lệnh không biết: {mnem}")
                pc += 1
        except AsmError as e:
            raise AsmError(f"dòng {n}: {e}") from None
    if pc > MEM_WORDS:
        raise AsmError(f"chương trình dài {pc} từ, vượt {MEM_WORDS}")

    # Lượt 2: mã hoá
    words, listing, pc = [], [], 0
    for n, label, mnem, ops, raw in lines:
        if mnem in (None, ".EQU"):
            listing.append(f"{'':16}{raw}")
            continue
        try:
            opcode, form = ISA[mnem]
            fields = form.split(",") if form else []
            if len(ops) != len(fields):
                raise AsmError(f"{mnem} cần {len(fields)} toán hạng")
            rd = rs = imm = 0
            for f, tok in zip(fields, ops):
                if f == "rd":
                    rd = parse_reg(tok)
                elif f == "rs":
                    rs = parse_reg(tok)
                else:
                    imm = eval_expr(tok, symbols)
                    if not -128 <= imm <= 255:
                        raise AsmError(f"giá trị tức thời ngoài phạm vi 8 bit: {imm}")
                    imm &= 0xFF
            word = (opcode << 12) | (rd << 10) | (rs << 8) | imm
        except AsmError as e:
            raise AsmError(f"dòng {n}: {e}") from None
        words.append(word)
        listing.append(f"{pc:02X}  {word:04X}      {raw}")
        pc += 1

    return words, listing, symbols


def main(argv):
    for stream in (sys.stdout, sys.stderr):
        stream.reconfigure(encoding="utf-8")  # console Windows mặc định cp1252
    if len(argv) != 3:
        print(__doc__)
        return 1
    src_path, hex_path = argv[1], argv[2]
    with open(src_path, encoding="utf-8") as f:
        src = f.read()
    try:
        words, listing, _ = assemble(src)
    except AsmError as e:
        print(f"{src_path}: lỗi: {e}", file=sys.stderr)
        return 1
    image = words + [FILL] * (MEM_WORDS - len(words))
    with open(hex_path, "w", encoding="ascii") as f:
        f.write("\n".join(f"{w:04X}" for w in image) + "\n")
    lst_path = re.sub(r"\.hex$", "", hex_path) + ".lst"
    with open(lst_path, "w", encoding="utf-8") as f:
        f.write("\n".join(listing) + "\n")
    print(f"{src_path}: {len(words)} lệnh -> {hex_path}, {lst_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
