#!/usr/bin/env python3
"""
Convert markdown files to well-formatted PDF using fpdf2.
Handles: headers, tables, code blocks, bold text, bullet points, horizontal rules.
"""
import re
import sys
import os
from fpdf import FPDF


def sanitize(text):
    """Replace Unicode chars that Helvetica can't render."""
    replacements = {
        '\u2705': '[OK]',      # check mark
        '\u274c': '[X]',       # cross mark
        '\u26a0\ufe0f': '[!]', # warning
        '\u26a0': '[!]',       # warning
        '\u2714': '[OK]',      # check
        '\u2718': '[X]',       # cross
        '\u25b6': '>',         # triangle
        '\u25bc': 'v',         # down triangle
        '\u2192': '->',        # arrow
        '\u2190': '<-',        # left arrow
        '\u2014': '--',        # em dash
        '\u2013': '-',         # en dash
        '\u2018': "'",         # left single quote
        '\u2019': "'",         # right single quote
        '\u201c': '"',         # left double quote
        '\u201d': '"',         # right double quote
        '\u2026': '...',       # ellipsis
        '\u2022': '-',         # bullet
        '\u2191': '^',         # up arrow
        '\u2193': 'v',         # down arrow
        '\u00d7': 'x',         # multiplication
        '\u2264': '<=',        # less than or equal
        '\u2265': '>=',        # greater than or equal
        '\u2500': '-',         # box drawing
        '\u250c': '+',         # box drawing
        '\u2510': '+',         # box drawing
        '\u2514': '+',         # box drawing
        '\u2518': '+',         # box drawing
        '\u251c': '+',         # box drawing
        '\u2524': '+',         # box drawing
        '\u2534': '+',         # box drawing
        '\u252c': '+',         # box drawing
        '\u253c': '+',         # box drawing
    }
    for k, v in replacements.items():
        text = text.replace(k, v)
    # Fallback: encode to latin-1, replacing anything else
    text = text.encode('latin-1', errors='replace').decode('latin-1')
    return text


class MarkdownPDF(FPDF):
    def __init__(self):
        super().__init__()
        self.set_auto_page_break(auto=True, margin=20)
        # Color palette
        self.SCOLLIA_BLUE = (38, 42, 118)  # #262A76
        self.DARK_GRAY = (51, 51, 51)      # #333333
        self.MED_GRAY = (102, 102, 102)    # #666666
        self.LIGHT_GRAY = (200, 200, 200)  # #C8C8C8
        self.TABLE_HEADER_BG = (38, 42, 118)
        self.TABLE_ALT_ROW = (245, 246, 250)  # #F5F6FA
        self.CODE_BG = (240, 240, 240)
        self.GREEN = (0, 176, 80)
        self.AMBER = (255, 192, 0)
        self.RED = (255, 0, 0)

    def header(self):
        pass

    def footer(self):
        self.set_y(-15)
        self.set_font("Helvetica", "I", 8)
        self.set_text_color(*self.MED_GRAY)
        self.cell(0, 10, f"Page {self.page_no()}/{{nb}}", align="C")

    def add_title_page(self, title, subtitle=""):
        self.add_page()
        self.ln(60)
        # Title
        self.set_font("Helvetica", "B", 28)
        self.set_text_color(*self.SCOLLIA_BLUE)
        self.multi_cell(0, 14, sanitize(title), align="C")
        # Subtitle
        if subtitle:
            self.ln(8)
            self.set_font("Helvetica", "", 12)
            self.set_text_color(*self.MED_GRAY)
            self.multi_cell(0, 8, sanitize(subtitle), align="C")
        # Decorative line
        self.ln(10)
        self.set_draw_color(*self.SCOLLIA_BLUE)
        self.set_line_width(0.8)
        x_start = self.w / 2 - 40
        self.line(x_start, self.get_y(), x_start + 80, self.get_y())

    def section_header(self, level, text):
        """Add a section header with proper formatting."""
        text = text.strip()
        # Clean markdown bold markers
        text = re.sub(r'\*\*(.+?)\*\*', r'\1', text)
        text = re.sub(r'\*(.+?)\*', r'\1', text)
        text = sanitize(text)

        if level == 1:
            self.ln(4)
            self.set_font("Helvetica", "B", 20)
            self.set_text_color(*self.SCOLLIA_BLUE)
            self.multi_cell(0, 10, text)
            # Underline
            self.set_draw_color(*self.SCOLLIA_BLUE)
            self.set_line_width(0.5)
            self.line(self.l_margin, self.get_y(), self.w - self.r_margin, self.get_y())
            self.ln(4)
        elif level == 2:
            self.ln(3)
            self.set_font("Helvetica", "B", 16)
            self.set_text_color(*self.SCOLLIA_BLUE)
            self.multi_cell(0, 9, text)
            self.ln(2)
        elif level == 3:
            self.ln(2)
            self.set_font("Helvetica", "B", 13)
            self.set_text_color(*self.SCOLLIA_BLUE)
            self.multi_cell(0, 8, text)
            self.ln(1)
        elif level == 4:
            self.ln(2)
            self.set_font("Helvetica", "B", 11)
            self.set_text_color(*self.DARK_GRAY)
            self.multi_cell(0, 7, text)
            self.ln(1)

    def add_table(self, headers, rows):
        """Add a formatted table."""
        if not headers or not rows:
            return

        # Sanitize all content first
        headers = [sanitize(re.sub(r'\*\*(.+?)\*\*', r'\1', h).strip()) for h in headers]
        rows = [[sanitize(re.sub(r'\*\*(.+?)\*\*', r'\1', c).strip()) for c in row] for row in rows]

        # Calculate column widths
        usable_width = self.w - self.l_margin - self.r_margin
        n_cols = len(headers)

        # Calculate max content width per column
        col_widths = []
        for i in range(n_cols):
            max_w = self.get_string_width(headers[i]) + 6
            for row in rows:
                if i < len(row):
                    w = self.get_string_width(row[i]) + 6
                    if w > max_w:
                        max_w = w
            col_widths.append(max_w)

        # Scale to fit usable width
        total = sum(col_widths)
        if total > usable_width:
            scale = usable_width / total
            col_widths = [w * scale for w in col_widths]
        elif total < usable_width and n_cols > 0:
            # Distribute extra space
            extra = (usable_width - total) / n_cols
            col_widths = [w + extra for w in col_widths]

        # Check if table fits on current page, if not add new page
        estimated_height = (len(rows) + 1) * 7
        if self.get_y() + estimated_height > self.h - 30:
            self.add_page()

        # Table header
        self.set_font("Helvetica", "B", 8)
        self.set_fill_color(*self.TABLE_HEADER_BG)
        self.set_text_color(255, 255, 255)
        self.set_draw_color(*self.LIGHT_GRAY)
        self.set_line_width(0.3)

        for i, header in enumerate(headers):
            self.cell(col_widths[i], 7, header, border=1, fill=True, align="C")
        self.ln()

        # Table rows
        self.set_font("Helvetica", "", 8)
        self.set_text_color(*self.DARK_GRAY)

        for row_idx, row in enumerate(rows):
            # Check page break
            if self.get_y() + 7 > self.h - 30:
                self.add_page()
                # Reprint header
                self.set_font("Helvetica", "B", 8)
                self.set_fill_color(*self.TABLE_HEADER_BG)
                self.set_text_color(255, 255, 255)
                for i, header in enumerate(headers):
                    self.cell(col_widths[i], 7, header, border=1, fill=True, align="C")
                self.ln()
                self.set_font("Helvetica", "", 8)
                self.set_text_color(*self.DARK_GRAY)

            # Alternating row colors
            if row_idx % 2 == 1:
                self.set_fill_color(*self.TABLE_ALT_ROW)
                fill = True
            else:
                self.set_fill_color(255, 255, 255)
                fill = True

            for i in range(n_cols):
                cell_text = row[i] if i < len(row) else ""

                # Truncate if too long
                max_chars = int(col_widths[i] / 1.8)
                if len(cell_text) > max_chars:
                    cell_text = cell_text[:max_chars-2] + ".."

                self.cell(col_widths[i], 7, cell_text, border=1, fill=fill)
            self.ln()

        self.ln(3)

    def add_code_block(self, code):
        """Add a formatted code block."""
        self.ln(2)
        self.set_font("Courier", "", 8)
        self.set_fill_color(*self.CODE_BG)
        self.set_text_color(*self.DARK_GRAY)
        self.set_draw_color(*self.LIGHT_GRAY)

        lines = code.strip().split('\n')
        for line in lines:
            if self.get_y() + 5 > self.h - 30:
                self.add_page()
            self.set_x(self.l_margin + 5)
            self.cell(self.w - self.l_margin - self.r_margin - 10, 5, sanitize(line), fill=True)
            self.ln()
        self.ln(3)

    def add_paragraph(self, text, bold=False, italic=False):
        """Add a text paragraph with inline formatting."""
        # Clean bold/italic markers for display
        display_text = text
        display_text = re.sub(r'\*\*(.+?)\*\*', r'\1', display_text)
        display_text = re.sub(r'\*(.+?)\*', r'\1', display_text)
        display_text = re.sub(r'`(.+?)`', r'\1', display_text)
        display_text = re.sub(r'~~(.+?)~~', r'\1', display_text)
        display_text = sanitize(display_text)

        if bold:
            self.set_font("Helvetica", "B", 10)
        elif italic:
            self.set_font("Helvetica", "I", 10)
        else:
            self.set_font("Helvetica", "", 10)

        self.set_text_color(*self.DARK_GRAY)
        self.multi_cell(0, 6, display_text)
        self.ln(1)

    def add_bullet(self, text, level=0):
        """Add a bullet point."""
        display_text = re.sub(r'\*\*(.+?)\*\*', r'\1', text)
        display_text = re.sub(r'\*(.+?)\*', r'\1', display_text)
        display_text = re.sub(r'`(.+?)`', r'\1', display_text)
        display_text = sanitize(display_text)

        indent = self.l_margin + 8 + (level * 8)
        self.set_x(indent)
        self.set_font("Helvetica", "", 10)
        self.set_text_color(*self.DARK_GRAY)
        bullet = "- " if level == 0 else "  - "
        self.cell(5, 6, bullet)
        self.multi_cell(self.w - indent - self.r_margin - 5, 6, display_text)
        self.ln(0.5)

    def add_horizontal_rule(self):
        """Add a horizontal line."""
        self.ln(4)
        self.set_draw_color(*self.LIGHT_GRAY)
        self.set_line_width(0.3)
        self.line(self.l_margin, self.get_y(), self.w - self.r_margin, self.get_y())
        self.ln(4)

    def add_bold_text_line(self, text):
        """Add a line that may contain bold segments."""
        display = re.sub(r'\*\*(.+?)\*\*', r'\1', text)
        display = re.sub(r'`(.+?)`', r'\1', display)
        display = sanitize(display)
        self.set_font("Helvetica", "B", 10)
        self.set_text_color(*self.DARK_GRAY)
        self.multi_cell(0, 6, display)
        self.ln(1)


def parse_table(lines, start_idx):
    """Parse a markdown table starting at start_idx. Returns (headers, rows, end_idx)."""
    headers = []
    rows = []
    idx = start_idx

    # Parse header row
    if idx < len(lines):
        line = lines[idx].strip()
        if line.startswith('|'):
            cells = [c.strip() for c in line.split('|')[1:-1]]
            headers = cells
            idx += 1

    # Skip separator line
    if idx < len(lines) and re.match(r'^\|[\s\-:|]+\|$', lines[idx].strip()):
        idx += 1

    # Parse data rows
    while idx < len(lines):
        line = lines[idx].strip()
        if not line.startswith('|'):
            break
        cells = [c.strip() for c in line.split('|')[1:-1]]
        rows.append(cells)
        idx += 1

    return headers, rows, idx


def convert_md_to_pdf(md_path, pdf_path):
    """Convert a markdown file to PDF."""
    with open(md_path, 'r', encoding='utf-8') as f:
        content = f.read()

    lines = content.split('\n')
    pdf = MarkdownPDF()
    pdf.alias_nb_pages()

    # Extract title from first H1
    title = "Document"
    subtitle = ""
    for line in lines:
        if line.startswith('# '):
            title = line[2:].strip()
            break

    # Add subtitle from first bold line after title
    for line in lines:
        if line.startswith('**') and '**' in line[3:]:
            subtitle = re.sub(r'\*\*(.+?)\*\*', r'\1', line).strip()
            break

    pdf.add_title_page(title, subtitle)

    i = 0
    in_code_block = False
    code_content = ""

    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        # Code block toggle
        if stripped.startswith('```'):
            if in_code_block:
                # End code block
                pdf.add_code_block(code_content)
                code_content = ""
                in_code_block = False
            else:
                # Start code block
                in_code_block = True
            i += 1
            continue

        if in_code_block:
            code_content += line + "\n"
            i += 1
            continue

        # Skip empty lines
        if not stripped:
            i += 1
            continue

        # Horizontal rule
        if re.match(r'^---+$', stripped) or re.match(r'^\*\*\*+$', stripped):
            pdf.add_horizontal_rule()
            i += 1
            continue

        # Headers
        if stripped.startswith('#'):
            match = re.match(r'^(#{1,4})\s+(.+)$', stripped)
            if match:
                level = len(match.group(1))
                text = match.group(2)
                pdf.section_header(level, text)
                i += 1
                continue

        # Table detection
        if stripped.startswith('|') and i + 1 < len(lines) and re.match(r'^\|[\s\-:|]+\|$', lines[i+1].strip()):
            headers, rows, end_idx = parse_table(lines, i)
            if headers and rows:
                pdf.add_table(headers, rows)
            i = end_idx
            continue

        # Bullet points
        if re.match(r'^[-*]\s', stripped):
            level = 0
            text = re.sub(r'^[-*]\s+', '', stripped)
            if stripped.startswith('  ') or stripped.startswith('\t'):
                level = 1
                text = re.sub(r'^[\s]+', '', text)
            # Clean markdown
            text = re.sub(r'\*\*(.+?)\*\*', r'\1', text)
            text = re.sub(r'`(.+?)`', r'\1', text)
            pdf.add_bullet(text, level)
            i += 1
            continue

        # Numbered list items
        if re.match(r'^\d+[\.\)]\s', stripped):
            text = re.sub(r'^\d+[\.\)]\s+', '', stripped)
            text = re.sub(r'\*\*(.+?)\*\*', r'\1', text)
            text = re.sub(r'`(.+?)`', r'\1', text)
            pdf.add_bullet(text, 0)
            i += 1
            continue

        # Regular paragraph
        # Check if it's a bold-only line (like a subsection header)
        clean = re.sub(r'\*\*(.+?)\*\*', r'\1', stripped)
        clean = re.sub(r'`(.+?)`', r'\1', clean)
        clean = re.sub(r'\*(.+?)\*', r'\1', clean)

        if stripped.startswith('**') and stripped.endswith('**') and stripped.count('**') == 2:
            pdf.add_bold_text_line(stripped)
        elif stripped.startswith('>'):
            # Blockquote
            text = stripped.lstrip('> ').strip()
            text = re.sub(r'\*\*(.+?)\*\*', r'\1', text)
            pdf.set_font("Helvetica", "I", 10)
            pdf.set_text_color(*pdf.MED_GRAY)
            pdf.multi_cell(0, 6, text)
            pdf.ln(1)
        else:
            pdf.add_paragraph(stripped)

        i += 1

    # Save
    pdf.output(pdf_path)
    print(f"Generated: {pdf_path}")
    print(f"Pages: {pdf.page_no()}")


if __name__ == "__main__":
    base_dir = os.path.dirname(os.path.abspath(__file__))

    files = [
        {
            "md": os.path.join(base_dir, "..", "..", "..", "PLAN_DASHBOARDS.md"),
            "pdf": os.path.join(base_dir, "PLAN_DASHBOARDS.pdf"),
            "title": "Plan de Implementacion: 9 Dashboards"
        },
        {
            "md": os.path.join(base_dir, "dashboard_blueprint.md"),
            "pdf": os.path.join(base_dir, "dashboard_blueprint.pdf"),
            "title": "Dashboard Blueprint"
        }
    ]

    for f in files:
        md_path = os.path.normpath(f["md"])
        pdf_path = os.path.normpath(f["pdf"])
        if os.path.exists(md_path):
            print(f"\nConverting: {md_path}")
            convert_md_to_pdf(md_path, pdf_path)
        else:
            print(f"NOT FOUND: {md_path}")
