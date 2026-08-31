# Linux Setup & Bootstrap Plan — mis-collections

> **ARCHIVED (2026-08-31).** Retired dated working/session note (Linux bootstrap + audit log, Phase A status)
> in favor of the single durable cross-platform guide `docs/DUAL_OS_SETUP.md`. Historical reference only.

## Status After Phase A (Completed)

- ✅ `/etc/group` confirms `docker:x:973:rtrlpz` — membership applied
- ✅ Docker access confirmed working under the `docker` group (tested via `newgrp docker`)
- ✅ `.env` created at project root with `POSTGRES_USER=rtrlpz`, ports 5433/8081
- ✅ Python 3.12.14 installed via uv, venv at `.venv` with all pinned deps (pandas 2.2.3, numpy 2.1.3, psycopg2 2.9.10, faker, pytest)

**Caveat:** Tool sessions spawned from the opencode process (started before `usermod`) don't inherit the docker group until a full logout/login. Workaround: wrap docker commands in `newgrp docker <<< '...'`. For persistent fix, log out/in and restart terminal/opencode.

---

## New Issue Discovered (Audit Finding)

`migrate.sh` is **NOT idempotent**: `001_create_tables.sql` uses plain `CREATE TABLE` for all 14 tables (no `IF NOT EXISTS`), while `003`/`005`/seeds/`007–010` are all guarded. So `bash database/migrate.sh` fails on 2nd run against existing schema. The compose file auto-mounts `./migrations:/docker-entrypoint-initdb.d`, which applies migrations on first boot — so `migrate.sh` re-running right after a fresh `up` conflicts. This will be fixed in Phase B: wrap 001's `CREATE TABLE` in `IF NOT EXISTS`.

---

## Phase C: Fresh Bootstrap Execution Plan

### 1. Start Database (auto-init via entrypoint)

```bash
docker compose --env-file .env -f database/docker-compose.yml up -d
```

- First boot: Postgres initializes empty volume, runs `database/migrations/001..010` automatically via `/docker-entrypoint-initdb.d` mount (alphabetical order = correct sequence).
- Wait for `pg_isready` (container restarts via `restart: always` until healthy).
- Verify: `docker logs postgres_collections` shows clean init.

### 2. Apply Seeds (idempotent; not in init mount)

```bash
for f in database/seeds/*.sql; do cat "$f" | newgrp docker <<< $'docker exec -i postgres_collections psql -v ON_ERROR_STOP=1 -U rtrlpz -d MIS_CollectionsDB >/dev/null'; done
```

Or run the seed portion of `migrate.sh` (skip 001-010, apply only 001-004 seeds).

### 3. Verify Schema

```bash
newgrp docker <<< $'docker exec postgres_collections psql -U rtrlpz -d MIS_CollectionsDB -c "SELECT COUNT(*) FROM pg_views WHERE schemaname=\x27public\x27 AND viewname LIKE \x27v\_%\x27;"'
```
Expected: **16** views.

```bash
newgrp docker <<< $'docker exec postgres_collections psql -U rtrlpz -d MIS_CollectionsDB -c "\dt"'
```
Expected: **15** tables (8 dim + 7 fact + etl_load_log).

### 4. Generate 12-Month Data (~90-150s)

```bash
UV_PROJECT_ENVIRONMENT=.venv uv run python data_sources/data_generator_v7.py
```
Output: ~1.9M rows across 14 CSV outputs in `data_sources/raw/`.

### 5. Load Data via ETL (~60s)

```bash
UV_PROJECT_ENVIRONMENT=.venv uv run python etl/data_to_pg.py
```

### 6. Run Fast Tests

```bash
UV_PROJECT_ENVIRONMENT=.venv uv run pytest test/ -v -m "not slow"
```
Expected: **81 tests passing** (0 failures).

---

## Phase B: Remaining Repo Fixes (to execute after bootstrap)

1. **`run_pipeline.sh`** — bash mirror of `run_pipeline.bat`:
   - Docker check → `docker compose` up → `pg_isready` wait
   - `--fresh` flag: `down -v` + bootstrap (steps 1-6 above)
   - Normal run: skip migrations, just generator + ETL
   - Per-stage timing, colored output, 16-view assertion

2. **Fix `migrate.sh` idempotency** — wrap 001's `CREATE TABLE` in `IF NOT EXISTS` (or DO block) so it's safely re-runnable.

3. **Update `run_pipeline.bat`** — use `docker compose` (v2) syntax for Windows consistency.

4. **Commit `.env.example`** — safe 7-var template; fix `QUICKSTART.md` reference.

5. **Docs sweep** — `QUICKSTART.md`, `TROUBLESHOOTING.md`, `AGENTS.md`:
   - `docker-compose` → `docker compose`
   - Add Linux commands (`./run_pipeline.sh`, `uv run ...`)
   - Add `fpdf` to `requirements.txt`

6. **Remove `.github/WORKFLOW/deploy.yml`** (empty, wrong path).

7. **Parametrize `import_measures.cs`** — resolve TSV path relative to script.

8. **Write `docs/DUAL_OS_SETUP.md`** — ownership split:
   - **Ubuntu = data factory** (Docker/Postgres, generator, ETL, tests, SQL analysis)
   - **Windows = Power BI** (PBIX, Tabular Editor, DAX CSV editing)
   - PBIX connects to Ubuntu Postgres via LAN IP:5433 (gitignored PBIX stays on Windows; DAX CSV is shared source of truth in git).

---

## Windows Power BI Connection

After bootstrap completes, Windows Power BI connects to the Ubuntu Postgres at:
- **Server:** `<Ubuntu-LAN-IP>:5433`
- **Database:** `MIS_CollectionsDB`
- **User:** `rtrlpz`
- **Password:** `rtrlpz` (from `.env`)

The compose port binding `- "5433:5432"` exposes 5433 on all interfaces — verify Ubuntu firewall allows inbound on 5433.

---

## Execution Order

| Phase | Description | Status |
|-------|-------------|--------|
| A | Docker group, Python 3.12 venv, .env | ✅ Done |
| C | Fresh bootstrap (DB → seeds → generate → ETL → tests) | ⏳ Next |
| B | Script fixes, docs, idempotency, dual-OS doc | ⏳ After C |