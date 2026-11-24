#!/usr/bin/env python3
"""Sinh docs/BaoCao.md từ báo cáo LaTeX (thư mục mẫu HUST), để hai bản luôn khớp nhau.

Chỉ xử lý tập lệnh LaTeX mà báo cáo này dùng: \\chaptercustom, \\subsection,
\\subsubsection, bảng tabular/tabularx, \\figurecustom, lstlisting, \\sig, \\textbf,
\\textit, \\cite, \\ref, một ít ký hiệu toán. Số thứ tự trích dẫn lấy từ file .bbl
của lần biên dịch gần nhất (thứ tự IEEE), nên cần biên dịch báo cáo trước.

Chạy từ thư mục gốc dự án:  python scripts/tex2md.py
"""
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
# thư mục báo cáo LaTeX và thư mục file phụ khi biên dịch
TPL = ROOT / "GraduationThesisTemplate-main - Copy" / "GraduationThesisTemplate-main"
AUX = Path(os.environ.get("TEMP", "/tmp")) / "tlc-report-aux"
CHAPTERS = ["MoDau/PhanCong.tex", "NoiDung/Chuong1.tex", "NoiDung/Chuong2.tex", "NoiDung/Chuong3.tex",
            "NoiDung/Chuong4.tex", "NoiDung/Chuong5.tex", "KetThuc/KetLuan.tex"]
# ký hiệu toán đổi sang Unicode
MATH = {r"\geq": "≥", r"\lor": "∨", r"\land": "∧", r"\lnot": "¬", r"\leftarrow": "←",
        r"\rightarrow": "→", r"\times": "×", r"\pm": "±", r"\star": "★", r"\mathit": "",
        "-": "−"}


# số thứ tự trích dẫn theo thứ tự \bibitem trong .bbl
def cite_numbers():
    bbl = next((p for p in (AUX / "main.bbl", TPL / "main.bbl") if p.exists()), None)
    if bbl is None:
        sys.exit("không thấy main.bbl: hãy biên dịch báo cáo trước")
    keys = re.findall(r"\\bibitem\{([^}]+)\}", bbl.read_text(encoding="utf-8"))
    return {k: i + 1 for i, k in enumerate(keys)}, bbl


def bib_entries(bbl):
    """Danh mục tham khảo dạng văn bản thường từ .bbl."""
    text = bbl.read_text(encoding="utf-8")
    out = []
    for item in re.split(r"\\bibitem\{[^}]+\}", text)[1:]:
        item = item.split("\\end{thebibliography}")[0]
        item = re.sub(r"\\BIBentry\w+|\\providecommand.*", "", item)
        item = re.sub(r"\\hskip.*?\\relax", " ", item, flags=re.S)   # khoảng cách của IEEEtran
        item = re.sub(r"\\url\{([^}]+)\}", r"\1", item)
        item = re.sub(r"\\emph\{([^{}]*(?:\{[^{}]*\}[^{}]*)*)\}", r"*\1*", item)
        item = item.replace("``", "“").replace("''", "”").replace("~", " ").replace("--", "–")
        item = re.sub(r"[{}]", "", " ".join(item.split()))
        out.append(item)
    return out


def label_numbers(chapters):
    """Gán số 'chương.thứ tự' cho mọi \\label của hình và bảng, và số mục cho \\label mục."""
    nums = {}
    for ch in chapters:
        src = (TPL / ch).read_text(encoding="utf-8")
        m = re.search(r"\\chaptercustom\{(\d+)\}", src)
        if not m:
            continue
        # bộ đếm hình, bảng, mục trong một chương
        c, fig, tab, sub = m.group(1), 0, 0, 0
        for tok in re.finditer(r"\\figurecustom\{[^}]*\}\{([^}]*)\}|\\begin\{table\}|"
                               r"\\label\{([^}]+)\}|\\subsection\{", src):
            # gặp hình
            if tok.group(1):
                fig += 1
                nums[tok.group(1)] = f"{c}.{fig}"
            elif tok.group(0).startswith("\\begin{table"):
                tab += 1
                cur_tab = f"{c}.{tab}"
            elif tok.group(0).startswith("\\subsection"):
                sub += 1
            elif tok.group(2):
                lab = tok.group(2)
                nums[lab] = cur_tab if lab.startswith("bang:") else f"{c}.{sub}"
    return nums


def member_names():
    """Tên thành viên khai báo trong main.tex: {'A': 'Thành viên 1', ...}."""
    src = (TPL / "main.tex").read_text(encoding="utf-8")
    return dict(re.findall(r"\\newcommand\{\\tv([A-F])\}\{([^}]*)\}", src))


MEMBERS = member_names()


# đổi lệnh LaTeX trong một dòng sang Markdown
def inline(s, cites, labels):
    s = re.sub(r"\\tv([A-F])\{\}", lambda m: MEMBERS.get(m.group(1), "?"), s)
    s = re.sub(r"\\cite\{([^}]+)\}",
               lambda m: "[" + ", ".join(str(cites.get(k.strip(), "?")) for k in m.group(1).split(",")) + "]", s)
    s = re.sub(r"\\ref\{([^}]+)\}", lambda m: labels.get(m.group(1), "?"), s)
    s = re.sub(r"\\texttt\{\\\{(.*?)\\\}\}", lambda m: "`{" + m.group(1).replace(
        "\\textquotesingle ", "'").replace("\\_", "_") + "}`", s)
    s = re.sub(r"\\sig\{((?:[^{}]|\{[^{}]*\})*)\}", lambda m: "`" + m.group(1) + "`", s)
    s = re.sub(r"\\texttt\{\\textdollar ([^}]*)\}", r"`$\1`", s)
    s = re.sub(r"\\textbf\{([^{}]*)\}", r"**\1**", s)
    s = re.sub(r"\\textit\{((?:[^{}]|\{[^{}]*\})*)\}", r"*\1*", s)

    # công thức trong cặp dấu $
    def math(m):
        t = m.group(1)
        for k, v in MATH.items():
            t = t.replace(k, v)
        return re.sub(r"[{}\\ ]", "", t).replace("^*", "*")
    s = re.sub(r"\$([^$]+)\$", math, s)
    s = s.replace("``", "“").replace("''", "”").replace("~", " ").replace("\\,", " ")
    s = s.replace("--", "–").replace("\\%", "%").replace("\\_", "_").replace("\\noindent", "")
    s = re.sub(r"\\(small|centering|hline|bfseries|setlength\{[^}]*\}\{[^}]*\})", "", s)
    return s.strip()


# đổi thân bảng tabular sang bảng Markdown
def table(body, cites, labels):
    rows = [r for r in body.split("\\\\") if r.strip() and r.strip() != "\\hline"]
    cells = [[inline(c, cites, labels) for c in r.replace("\\hline", "").split("&")] for r in rows]
    cells = [r for r in cells if any(r)]
    if not cells:
        return ""
    # hàng thiếu ô thì thêm ô trống
    w = max(len(r) for r in cells)
    cells = [r + [""] * (w - len(r)) for r in cells]
    out = ["| " + " | ".join(cells[0]) + " |", "|" + " --- |" * w]
    out += ["| " + " | ".join(r) + " |" for r in cells[1:]]
    return "\n".join(out)


def convert(src, cites, labels):
    md = []
    # khối mã và bảng xử lý trước, thay bằng chỗ giữ tạm
    blocks = []

    # cất khối đã xử lý, trả về chỗ giữ tạm
    def keep(text):
        blocks.append(text)
        return f"\n@@BLOCK{len(blocks) - 1}@@\n"

    src = re.sub(r"\\begin\{lstlisting\}(\[[^\]]*\])?\n(.*?)\\end\{lstlisting\}",
                 lambda m: keep("```\n" + m.group(2).rstrip() + "\n```"), src, flags=re.S)

    # xử lý một môi trường table
    def tbl(m):
        env = m.group(0)
        cap = re.search(r"\\tcap\{([^}]*)\}", env)
        body = re.search(r"\\begin\{tabularx?\}(?:\{\\textwidth\})?\{[^\n]*?\}\s*\n(.*?)\\end\{tabularx?\}", env, re.S)
        lab = re.search(r"\\label\{([^}]+)\}", env)
        note = re.search(r"\\textit\{(\$\^\{\*\}\$.*?)\}\s*\n\\end\{table\}", env, re.S)
        head = f"*Bảng {labels.get(lab.group(1), '?')}. {cap.group(1)}*\n\n" if cap and lab else ""
        tail = "\n\n" + inline("\\textit{" + note.group(1) + "}", cites, labels) if note else ""
        return keep(head + table(body.group(1), cites, labels) + tail) if body else ""
    src = re.sub(r"\\begin\{table\}.*?\\end\{table\}", tbl, src, flags=re.S)

    # chú thích hình, bỏ dấu thoát của gạch dưới
    def cap(m):
        return m.group(2).replace(chr(92) + "_", "_")

    src = re.sub(r"\\figurecustom\{[^}]*\}\{Images/([^}]*)\}\{([^}]*)\}",
                 lambda m: keep(f"![{cap(m)}](figures/{m.group(1)})\n\n"
                                f"*Hình {labels.get('Images/' + m.group(1), '?')}. {cap(m)}*"), src)

    # phần còn lại xử lý từng dòng
    for line in src.split("\n"):
        t = line.strip()
        if not t or t.startswith("%") or re.match(r"\\(setcounter|cleardoublepage|phantomsection|addcontentsline)", t):
            md.append("")
            continue
        m = re.match(r"\\chaptercustom\{(\d+)\}\{(.*)\}", t)
        if m:
            md.append(f"## Chương {m.group(1)}. {m.group(2).capitalize()}")
            continue
        m = re.match(r"\\phantomsection\\section\*\{\\centering (.*)\}", t) or re.match(r"\\section\*\{\\centering (.*)\}", t)
        if m:
            md.append(f"## {m.group(1).capitalize()}")
            continue
        m = re.match(r"(?:\\phantomsection)?\\(sub)?subsection(\*?)\{(.*)\}", t)
        if m:
            md.append(("#### " if m.group(1) else "### ") + inline(m.group(3), cites, labels))
            continue
        if re.match(r"\\(begin|end)\{(itemize|enumerate)\}|\\label\{", t):
            continue
        m = re.match(r"\\item\s*(.*)", t)
        if m:
            md.append("- " + inline(m.group(1), cites, labels))
            continue
        if t.startswith("@@BLOCK"):
            md.append(t)
            continue
        md.append(inline(t, cites, labels))
    text = "\n".join(md)
    # đặt lại các khối đã cất
    text = re.sub(r"@@BLOCK(\d+)@@", lambda m: blocks[int(m.group(1))], text)
    return re.sub(r"\n{3,}", "\n\n", text).strip()


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    cites, bbl = cite_numbers()
    labels = label_numbers(CHAPTERS)
    title = ("Thiết kế và so sánh các phương pháp hiện thực bộ điều khiển đèn giao thông "
             "trên Verilog: FSM cứng, vi chương trình và CPU mini")
    parts = [f"# {title}",
             "Bản Markdown sinh tự động từ báo cáo LaTeX bằng `scripts/tex2md.py`; "
             "bản chính để nộp là PDF biên dịch từ thư mục mẫu HUST.",
             convert((TPL / "MoDau/CamOnvaTomTat.tex").read_text(encoding="utf-8")
                     .split("\\subsection*{\\centering Tóm tắt nội dung báo cáo}")[1].split("\\vfill")[0],
                     cites, labels).join(["## Tóm tắt\n\n", ""])]
    for ch in CHAPTERS:
        parts.append(convert((TPL / ch).read_text(encoding="utf-8"), cites, labels))
    # danh mục tham khảo ở cuối
    parts.append("## Tài liệu tham khảo\n\n" +
                 "\n".join(f"{i}. {e}" for i, e in enumerate(bib_entries(bbl), 1)))
    out = ROOT / "docs" / "BaoCao.md"
    out.write_text("\n\n".join(parts) + "\n", encoding="utf-8")
    print(f"-> {out.relative_to(ROOT)} ({len(out.read_text(encoding='utf-8').split())} từ)")


if __name__ == "__main__":
    main()
