#!/usr/bin/env python3
"""
Generate a definitive DAX reference .md file from collections_dax_v2.csv
Shows all measures as formatted DAX code blocks, organized by table.
"""
import csv
import os
import re

CSV_PATH = os.path.join(os.path.dirname(__file__), "collections_dax_v2.csv")
OUT_PATH = os.path.join(os.path.dirname(__file__), "..", "..", "docs", "dashboards", "dax_measures_all.md")

# Table display order and descriptions
TABLE_INFO = {
    "_Outreach & Activity": "Base contact metrics, agent productivity, and handle time.",
    "_Promise & Recovery": "Promise-to-pay pipeline, KP%, BB Conversion, Capped KP, cures, recovery amounts, payment methods.",
    "_Portfolio Health": "EOM snapshot, DPD buckets, arrears, roll rates, migration, skip-path analysis.",
    "_Goals & Targets": "Goal values, gaps, RAG status, color hex for 7 key KPI metrics.",
    "_Composites & Strategy": "Composite scores, agent metrics, dialer performance, financial efficiency, vintage analysis, credit risk.",
    "_Time Intelligence": "Calculation Group — MoM, WoW, DoD, YoY, OTC, YTD, Rolling 3M (18 items). Apply as slicer to any base measure.",
}

CG_JSON_PATH = os.path.join(os.path.dirname(__file__), "calculation_group_ti.json")


def clean_expression(expr):
    """Clean CSV-escaped DAX expression for display."""
    expr = expr.strip()
    if expr.startswith('"') and expr.endswith('"'):
        expr = expr[1:-1]
    expr = expr.replace('""', '"')
    return expr.strip()


def load_cg_items():
    """Load Calculation Group items from JSON."""
    import json
    if not os.path.exists(CG_JSON_PATH):
        return []
    with open(CG_JSON_PATH, "r", encoding="utf-8") as f:
        cg = json.load(f)
    return cg.get("calculationItems", [])

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
    lines.append(f"**Source:** `dashboards/dax/collections_dax_v2.csv`")
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

        # Special handling for Time Intelligence: legacy measures + CG reference
        if table_name == "_Time Intelligence":
            lines.append("> **Note:** These 118 legacy measures are preserved for backward compatibility.")
            lines.append("> They are **replaced** by the `_Time Intelligence` Calculation Group (18 items).")
            lines.append("> Once the CG is verified, delete these individual measures from the model.")
            lines.append("")
            lines.append("### Legacy Measures (118)")
            lines.append("")
            for m in measures:
                lines.append(f"**{m['name']}**")
                lines.append("")
                lines.append("```dax")
                lines.append(m["expression"])
                lines.append("```")
                lines.append("")
            lines.append("---")
            lines.append("")
            lines.append("### Calculation Group (18 items)")
            lines.append("")
            lines.append("Apply `_Time Intelligence[Calculation Item]` as a slicer/filter to any base measure.")
            lines.append("")
            cg_items = load_cg_items()
            for item in cg_items:
                name = item.get("name", "?")
                expr = item.get("expression", "")
                fmt = item.get("formatString", "inherit")
                ordinal = item.get("ordinal", 0)
                lines.append(f"**{ordinal}. {name}** — Format: `{fmt}`")
                lines.append("")
                lines.append("```dax")
                lines.append(expr)
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
