# MIS Collections — Quick Start (5-minute setup)

## Prerequisites

- Python 3.10+ with [conda](https://docs.conda.io/)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- Git Bash (Windows) or bash (Linux/Mac)

## Setup

```bash
# 1. Create conda environment
conda create -n mis-collections python=3.12 -y
conda activate mis-collections
pip install -r requirements.txt

# 2. Configure environment
copy .env.example .env    # Windows
# cp .env.example .env    # Linux/Mac
# Edit .env with your credentials (defaults work for local dev)

# 3. Start PostgreSQL
docker-compose -f database/docker-compose.yml up -d

# 4. Run full pipeline (generate, migrate, load)
./run_pipeline.bat         # Windows
# bash database/migrate.sh && python data_sources/data_generator_v7.py && python etl/data_to_pg.py

# 5. Verify
python -m pytest test/ -v -m "not slow"
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

## Troubleshooting

- **Docker not running**: Start Docker Desktop and wait for the whale icon
- **Port conflict**: Change `POSTGRES_PORT` in `.env` from 5433 to another port
- **Conda env not found**: Run `conda info --envs` to verify `mis-collections` exists
- See `TROUBLESHOOTING.md` for detailed error resolution
