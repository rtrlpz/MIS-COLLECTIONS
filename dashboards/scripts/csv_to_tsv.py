import csv
from pathlib import Path
DAX = Path(__file__).parent.parent / "dax"
INPUT = DAX / "collections_dax_v2.csv"
OUTPUT = DAX / "measures.tsv"
rows = []
with open(INPUT, newline="", encoding="utf-8") as f:
    for r in csv.reader(f):
        rows.append(r)
with open(OUTPUT, "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f, delimiter="\t")
    for r in rows:
        w.writerow(r)
measure_count = len(rows) - 1  # minus header
print(f"Done: {OUTPUT} ({measure_count} measures)")
