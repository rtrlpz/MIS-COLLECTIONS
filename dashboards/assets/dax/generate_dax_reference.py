#!/usr/bin/env python3
"""
Generate a definitive DAX reference .md file from collections_dax_v2.csv
Shows all measures as formatted DAX code blocks, organized by table.
"""
import csv
import os
import re

CSV_PATH = os.path.join(os.path.dirname(__file__), "collections_dax_v2.csv")
OUT_PATH = os.path.join(os.path.dirname(__file__), "..", "docs", "dax_measures_all.md")

# Table display order and descriptions
TABLE_INFO = {
    "_Outreach & Activity": "Base contact metrics, agent productivity, and handle time.",
    "_Promise & Conversion": "Promise-to-pay pipeline, KP%, BB Conversion, Capped KP.",
    "_Recovery & Collection": "Cures, collection amounts, payment method breakdown.",
    "_Portfolio Health": "EOM snapshot metrics, DPD bucket distribution, arrears, roll rates.",
    "_Goals & Targets": "Goal values, gaps, RAG status, color hex for 7 key KPI metrics.",
    "_Time Intelligence": "MoM, WoW, DoD, YoY, OTC, YTD, and rolling window calculations.",
    "_Executive": "VP-level portfolio health metrics for Executive Collections dashboard.",
    "_Agent Performance": "Individual agent metrics for leaderboard and coaching.",
    "_Dialer Performance": "Dialer campaign efficiency metrics.",
    "_Portfolio Management": "Portfolio-level risk and concentration metrics.",
    "_Financial Recovery": "Financial recovery efficiency and cost metrics.",
    "_Vintage Analysis": "Vintage (open_date) age and balance metrics.",
    "_Roll Rate Analysis": "Roll rate trend and net migration metrics.",
}

# Time Intelligence sub-sections
TI_SECTIONS = {
    "MoM": "Month-over-Month",
    "WoW": "Week-over-Week",
    "DoD": "Day-over-Day",
    "YoY": "Year-over-Year",
    "OTC": "Overall-to-Current",
    "YTD": "Year-to-Date",
    "Rolling": "Rolling Window",
}

def clean_expression(expr):
    """Clean CSV-escaped DAX expression for display."""
    # Remove outer quotes if present
    expr = expr.strip()
    if expr.startswith('"') and expr.endswith('"'):
        expr = expr[1:-1]
    # Unescape doubled quotes
    expr = expr.replace('""', '"')
    # Unescape triple quotes (CSV artifact)
    expr = expr.replace('"""', '"')
    return expr.strip()

def classify_ti_measure(name):
    """Classify a Time Intelligence measure into its sub-section."""
    if "WoW" in name or "Prior Week" in name:
        return "WoW"
    elif "DoD" in name or "Prior Day" in name:
        return "DoD"
    elif "YoY" in name or "Prior Year" in name:
        return "YoY"
    elif "OTC" in name or "Overall" in name:
        return "OTC"
    elif "YTD" in name:
        return "YTD"
    elif "Rolling" in name:
        return "Rolling"
    else:
        return "MoM"

def generate_md():
    # Read CSV
    rows = []
    with open(CSV_PATH, "r", encoding="utf-8") as f:
        reader = csv.reader(f)
        header = next(reader)
        for row in reader:
            if len(row) >= 3:
                rows.append({
                    "table": row[0].strip(),
                    "name": row[1].strip(),
                    "expression": clean_expression(row[2]),
                })

    # Group by table
    from collections import OrderedDict
    tables = OrderedDict()
    for row in rows:
        t = row["table"]
        if t not in tables:
            tables[t] = []
        tables[t].append(row)

    # Build markdown
    lines = []
    lines.append("# DAX Measures — Complete Reference")
    lines.append("")
    lines.append(f"**Total Measures:** {len(rows)}")
    lines.append(f"**Source:** `dashboards/assets/dax/collections_dax_v2.csv`")
    lines.append("")
    lines.append("---")
    lines.append("")

    # Table of contents
    lines.append("## Table of Contents")
    lines.append("")
    for table_name in tables:
        count = len(tables[table_name])
        anchor = table_name.lower().replace(" ", "-").replace("&", "").replace("_", "")
        lines.append(f"- [{table_name}](#{anchor}) ({count} measures)")
    lines.append("")
    lines.append("---")
    lines.append("")

    # Each table section
    for table_name, measures in tables.items():
        desc = TABLE_INFO.get(table_name, "")
        lines.append(f"## {table_name}")
        lines.append("")
        if desc:
            lines.append(f"*{desc}*")
            lines.append("")

        # Special handling for Time Intelligence: split into sub-sections
        if table_name == "_Time Intelligence":
            ti_groups = OrderedDict()
            for sec_key in TI_SECTIONS:
                ti_groups[sec_key] = []

            for m in measures:
                sec = classify_ti_measure(m["name"])
                ti_groups[sec].append(m)

            for sec_key, sec_label in TI_SECTIONS.items():
                sec_measures = ti_groups.get(sec_key, [])
                if not sec_measures:
                    continue
                lines.append(f"### {sec_key} — {sec_label} ({len(sec_measures)} measures)")
                lines.append("")
                for m in sec_measures:
                    lines.append(f"**{m['name']}**")
                    lines.append("")
                    lines.append("```dax")
                    lines.append(m["expression"])
                    lines.append("```")
                    lines.append("")

        # Special handling for Goals & Targets: split calculated tables vs measures
        elif table_name == "_Goals & Targets":
            calc_tables = [m for m in measures if m["expression"].startswith("DATATABLE")]
            goal_measures = [m for m in measures if not m["expression"].startswith("DATATABLE")]

            if calc_tables:
                lines.append("### Calculated Tables")
                lines.append("")
                for m in calc_tables:
                    lines.append(f"**{m['name']}**")
                    lines.append("")
                    lines.append("```dax")
                    lines.append(m["expression"])
                    lines.append("```")
                    lines.append("")

            if goal_measures:
                lines.append("### Measures")
                lines.append("")
                for m in goal_measures:
                    lines.append(f"**{m['name']}**")
                    lines.append("")
                    lines.append("```dax")
                    lines.append(m["expression"])
                    lines.append("```")
                    lines.append("")

        # All other tables: flat list
        else:
            for m in measures:
                lines.append(f"**{m['name']}**")
                lines.append("")
                lines.append("```dax")
                lines.append(m["expression"])
                lines.append("```")
                lines.append("")

        lines.append("---")
        lines.append("")

    # Write output
    os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
    with open(OUT_PATH, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

    print(f"Generated: {OUT_PATH}")
    print(f"Total measures: {len(rows)}")
    print(f"Tables: {len(tables)}")
    for t, m in tables.items():
        print(f"  {t}: {len(m)}")


if __name__ == "__main__":
    generate_md()
