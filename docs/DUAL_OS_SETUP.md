# Dual-OS Development Setup: Ubuntu (Data Factory) + Windows (Power BI)

This document describes the recommended workflow for developing MIS Collections across **Ubuntu (Linux)** and **Windows** simultaneously.

---

## Ownership Split

| Layer | Ubuntu (Linux) | Windows |
|-------|----------------|---------|
| **PostgreSQL Database** | ✅ Runs in Docker (`postgres_collections`) | ❌ Not needed |
| **Data Generation** | ✅ `data_sources/data_generator_v7.py` | ❌ Not needed |
| **ETL / Loading** | ✅ `etl/data_to_pg.py` | ❌ Not needed |
| **SQL Analysis** | ✅ 17 analysis queries, KPI views | ❌ Not needed |
| **Testing** | ✅ `pytest test/` (81 fast + 3 slow) | ❌ Not needed |
| **Power BI (.pbix)** | ❌ Gitignored, not portable | ✅ Primary development |
| **DAX Measures (CSV)** | ✅ Source of truth in git (`dashboards/dax/collections_dax_v2.csv`) | ✅ Edit & import into PBIX |
| **Tabular Editor Scripts** | ❌ Windows-only (.NET) | ✅ `import_measures.cs`, `create_calc_group.cs` |
| **Excel Reporting** | ❌ Phase 10 pending | ✅ `openpyxl` generator |

---

## Data Flow

```
Ubuntu (Data Factory)                    Windows (Power BI)
┌─────────────────────────┐              ┌─────────────────────────┐
│ docker compose up       │              │ Power BI Desktop        │
│ generate 12-mo data     │   LAN:5433   │ connects to Ubuntu PG   │
│ ETL → PostgreSQL        │ ◄──────────► │ imports DAX from CSV    │
│ run pytest              │   (exposed)  │ Tabular Editor scripts  │
└─────────────────────────┘              └─────────────────────────┘
        ▲                                        │
        │ git push/pull (DAX CSV, SQL, Python)   │
        └────────────────────────────────────────┘
```

**Key principle:** The **Linux PostgreSQL is the single source of truth for data**. Windows Power BI connects to it over the LAN. The **DAX CSV is the single source of truth for measures** (shared via git).

---

## Ubuntu Setup (One-time)

```bash
# 1. Docker group (so you don't need sudo)
sudo usermod -aG docker $USER
# Log out and back in (or run: newgrp docker)

# 2. Python env (uv recommended)
uv python install 3.12
uv venv --python 3.12 .venv
uv pip install -r requirements.txt

# 3. Environment config
cp .env.example .env
# Edit .env if needed (defaults work for local dev)

# 4. Fresh bootstrap (run once)
./run_pipeline.sh --fresh
# This: down -v → up → migrate → generate 12-mo → ETL → tests

# 5. Daily development
./run_pipeline.sh          # normal: generate + ETL (skips migrations)
uv run pytest test/ -v -m "not slow"  # fast tests
```

---

## Windows Setup (One-time)

1. **Clone the repo** (same repo, different machine)
2. **Install Docker Desktop** (for `docker` CLI if needed, but PBIX doesn't need it)
3. **Install Power BI Desktop** (latest)
4. **Install Tabular Editor 2/3** (for DAX measure import)
5. **Python env** (optional, only if you want to run generator/ETL locally):
   - `conda create -n mis-collections python=3.12` + `pip install -r requirements.txt`
   - OR `uv venv --python 3.12 .venv` + `uv pip install -r requirements.txt`
6. **Configure PBIX data source**:
   - Get Ubuntu's LAN IP: `ip addr show` (on Ubuntu) → e.g., `192.168.1.42`
   - In Power BI Desktop: **Get Data → PostgreSQL**
     - Server: `192.168.1.42:5433`
     - Database: `MIS_CollectionsDB`
     - User: `rtrlpz`
     - Password: `rtrlpz` (from Ubuntu's `.env`)
   - **Import** → **DirectQuery** (live) or **Import** (snapshot)
7. **Import DAX measures** (in Tabular Editor):
   - Open PBIX in Tabular Editor
   - Run `dashboards/scripts/import_measures.cs` (auto-resolves `measures.tsv`)
   - Run `dashboards/scripts/create_calc_group.cs` for Time Intelligence CG

---

## Daily Workflow

### On Ubuntu (Data Engineer)

```bash
# 1. Pull latest DAX/SQL/Python changes
git pull

# 2. Regenerate data if schema/logic changed
./run_pipeline.sh          # incremental (fast)
# or: ./run_pipeline.sh --fresh  # full rebuild

# 3. Run tests
uv run pytest test/ -v -m "not slow"

# 4. Push DAX/measure changes
git add dashboards/dax/collections_dax_v2.csv
git commit -m "Update DAX: <description>"
git push
```

### On Windows (Power BI Analyst)

```bash
# 1. Pull latest DAX measures
git pull

# 2. Refresh PBIX from Ubuntu DB
# Power BI Desktop: Home → Refresh (if Import mode)
# Or just use DirectQuery for live data

# 3. Update DAX measures in Tabular Editor
# Open PBIX in Tabular Editor → Run import_measures.cs

# 4. Push DAX changes back to git
git add dashboards/dax/collections_dax_v2.csv
git commit -m "DAX: <description>"
git push
```

---

## Network / Firewall Notes

- Ubuntu exposes PostgreSQL on **0.0.0.0:5433** (see `docker-compose.yml`)
- Windows connects to `<Ubuntu-LAN-IP>:5433`
- Ensure Ubuntu firewall allows inbound on 5433:
  ```bash
  sudo ufw allow 5433/tcp   # if ufw is active
  # or: sudo firewall-cmd --permanent --add-port=5433/tcp && sudo firewall-cmd --reload
  ```
- If using Docker Desktop on Windows with WSL2, you can also use `host.docker.internal:5433` from Windows

---

## File Sync Rules

| File / Dir | Synced via Git? | Notes |
|------------|-----------------|-------|
| `dashboards/dax/*.csv` | ✅ | Source of truth for measures |
| `dashboards/dax/*.json` | ✅ | Calculation Group definition |
| `dashboards/pbix/*.pbix` | ❌ | Gitignored — stays on Windows |
| `data_sources/raw/` | ❌ | Gitignored — generated on Ubuntu |
| `database/data/` | ❌ | Gitignored — PG volume on Ubuntu |
| `.env` | ❌ | Gitignored — per-machine |
| All Python/SQL/MD | ✅ | Core logic shared |

---

## Troubleshooting

| Issue | Resolution |
|-------|------------|
| Windows PBIX can't connect to Ubuntu PG | Check Ubuntu firewall (`ufw status`), verify LAN IP, test `telnet <IP> 5433` from Windows |
| DAX import fails in Tabular Editor | Ensure `measures.tsv` exists (run `python dashboards/scripts/csv_to_tsv.py` on Ubuntu or Windows), check script path resolution |
| Ubuntu `docker compose` permission denied | `sudo usermod -aG docker $USER` → log out/in |
| Python version mismatch | Both sides use Python 3.12 (via uv or conda) |
| Schema drift after git pull | Run `bash migrate.sh` on Ubuntu (idempotent) |

---

## Quick Reference

| Task | Ubuntu Command | Windows Command |
|------|----------------|-----------------|
| Start DB | `docker compose --env-file .env -f database/docker-compose.yml up -d` | N/A (connects to Ubuntu) |
| Full pipeline | `./run_pipeline.sh --fresh` | `./run_pipeline.bat` |
| Incremental pipeline | `./run_pipeline.sh` | N/A |
| Generate only | `uv run python data_sources/data_generator_v7.py` | `uv run python data_sources/data_generator_v7.py` |
| ETL only | `uv run python etl/data_to_pg.py` | `uv run python etl/data_to_pg.py` |
| Migrations | `bash migrate.sh` / `bash migrate.sh --fresh` | N/A |
| Tests | `uv run pytest test/ -v -m "not slow"` | `uv run pytest test/ -v -m "not slow"` |
| DAX import | N/A | Tabular Editor → `import_measures.cs` |
| Time Intelligence CG | N/A | Tabular Editor → `create_calc_group.cs` |

---

## Version Compatibility

- **Python:** 3.12 (enforced by pinned `pandas==2.2.3`, `numpy==2.1.3`)
- **PostgreSQL:** 15 (Docker image `postgres:15`)
- **Docker Compose:** v2 (`docker compose` — space, not hyphen)
- **Power BI Desktop:** Latest (Import or DirectQuery mode)
- **Tabular Editor:** 2.x or 3.x (for DAX import scripts)

---

*Last updated: Phase B (Aug 2026) — reflects `run_pipeline.sh`, idempotent `migrate.sh`, `docker compose` v2, uv Python env.*