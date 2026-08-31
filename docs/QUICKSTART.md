# MIS Collections — Quick Start (5-minute setup)

## Prerequisites

- Python 3.12+ (system or via [uv](https://github.com/astral-sh/uv) / [conda](https://docs.conda.io/))
- Docker Engine + Compose v2 (`docker compose`)
- Git Bash (Windows) or bash (Linux/macOS)

## Setup

```bash
# 1. Create Python 3.12 environment (uv recommended, or conda)
# uv (fast, already on many systems):
uv python install 3.12
uv venv --python 3.12 .venv
uv pip install -r requirements.txt

# OR conda (Windows parity):
conda create -n mis-collections python=3.12 -y
conda activate mis-collections
pip install -r requirements.txt

# 2. Configure environment
cp .env.example .env    # Linux/macOS
# copy .env.example .env    # Windows (cmd)
# Edit .env with your credentials (defaults work for local dev)

# 3. Start PostgreSQL (Compose v2 syntax)
docker compose --env-file .env -f database/docker-compose.yml up -d

# 4. Run full pipeline
# Linux/macOS (new unified script):
./run_pipeline.sh              # normal: generate + ETL (skips migrations if DB exists)
./run_pipeline.sh --fresh      # full rebuild: down -v + bootstrap + generate + ETL

# Windows (updated .bat uses docker compose v2):
./run_pipeline.bat

# Legacy manual steps (still work):
# bash migrate.sh && python data_sources/data_generator_v7.py && python etl/data_to_pg.py

# 5. Verify
uv run pytest test/ -v -m "not slow"
# or: python -m pytest test/ -v -m "not slow"
```

## Expected output

| Step | Time | Result |
|------|------|--------|
| Docker start | ~5s | Container `postgres_collections` running on port 5433 |
| Migrations | ~2s | 10 migration files applied, 16 views created |
| Data generation | ~90s | ~1.9M rows across 14 CSV outputs (12 months) |
| ETL load | ~60s | ~1.9M rows in PostgreSQL |
| Tests | ~5 min fast / ~15 min full gate | 81 fast pass · 84 total (0 failures) |

## Directory structure

```
.
├── data_sources/               # Data generator (v7)
├── database/                  # Docker + SQL (migrations, seeds)
├── etl/                       # CSV → PostgreSQL loader
├── analysis/                  # 17 analytical queries
├── dashboards/                # Power BI files + DAX measures
├── test/                      # pytest test suite
└── docs/                      # Documentation
```

## Linux/macOS notes

- Use `docker compose` (v2, space) not `docker-compose` (v1, hyphen)
- Add yourself to `docker` group: `sudo usermod -aG docker $USER` then log out/in
- uv is recommended for Python env management (faster than conda)
- `run_pipeline.sh` provides `--fresh` (full rebuild) and normal (incremental) modes

## Troubleshooting

- **Docker not running**: Start Docker daemon (`sudo systemctl start docker`) and verify with `docker ps`
- **Port conflict**: Change `POSTGRES_PORT` in `.env` from 5433 to another port
- **Permission denied (Docker)**: Run `sudo usermod -aG docker $USER`, log out/in, or use `newgrp docker`
- **Conda/uv env not found**: Verify `uv python list` or `conda info --envs`
- See `TROUBLESHOOTING.md` for detailed error resolution