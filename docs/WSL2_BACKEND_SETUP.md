# WSL2 Backend Setup for Cross-Platform Development

## Objective
Enable a single PostgreSQL instance (running in WSL2 via Docker Desktop) accessible from both Windows and Linux environments for the mis-collections project.

## Prerequisites
- Windows 10/11 with WSL2 installed
- Docker Desktop for Windows installed
- Ubuntu (or other) WSL2 distribution
- Project cloned in a location accessible from both Windows and WSL2 (e.g., `/home/rtrlpz/projects-portfolio/mis-collections`)

---

## Step 1: Enable WSL2 Backend in Docker Desktop (Manual - One Time)

### In Docker Desktop (Windows):
1. Open **Docker Desktop** → **Settings** (gear icon)
2. Go to **General** tab
3. Check ✅ **"Use the WSL 2 based engine"**
4. Click **Apply & Restart**
5. After restart, go to **Resources** → **WSL Integration**
6. Enable integration for your WSL2 distro (e.g., `Ubuntu`)
7. Click **Apply & Restart** again

### Verify:
```powershell
# From PowerShell
docker version
docker info | findstr "Operating System"
# Should show: Operating System: Linux (WSL2)
```

```bash
# From WSL2 terminal (Ubuntu)
docker version
docker ps
# Should show same containers as Windows
```

---

## Step 2: Verify Current Configuration Compatibility

### Current `.env` (Already Compatible)
```env
POSTGRES_HOST=localhost
POSTGRES_PORT=5433
```
- `localhost` works from **both** Windows and WSL2 when using WSL2 backend
- Port 5433 mapped on host (Windows/WSL2) → 5432 in container

### Current `docker-compose.yml` (Already Compatible)
```yaml
ports:
  - "${POSTGRES_PORT}:5432"  # 5433:5432
```
- Port binding works identically in WSL2 backend mode

### Current Scripts (Already Compatible)
- `run_pipeline.bat` → Uses `docker compose` from Windows, connects to `localhost:5433`
- `run_pipeline.sh` → Uses `docker compose` from Linux, connects to `localhost:5433` (via WSL2)
- `etl/data_to_pg.py` → Reads `POSTGRES_HOST=localhost` from `.env`

**No code changes required** — existing configuration works out of the box.

---

## Step 3: Cross-Platform Workflow

### Scenario A: Working from Windows (Primary)
```powershell
# Terminal: PowerShell or CMD
cd C:\Users\Leand\Desktop\Portafolio-Projects\mis-collections

# Full pipeline (fresh)
.\run_pipeline.bat

# Or incremental
.\run_pipeline.bat --etl
```

### Scenario B: Working from Linux/WSL2
```bash
# Terminal: WSL2 (Ubuntu) or native Linux
cd /home/rtrlpz/projects-portfolio/mis-collections

# Full pipeline (fresh)
./run_pipeline.sh --fresh

# Or normal
./run_pipeline.sh
```

### Scenario C: Switching Mid-Work
1. Stop containers from current platform: `docker compose down`
2. Switch to other platform
3. Start containers: `docker compose up -d`
4. Continue work — **same database, same data**

---

## Step 4: Data Persistence

### Volume Location
```yaml
volumes:
  - ./data:/var/lib/postgresql/data
```
- **Windows path**: `C:\Users\Leand\Desktop\Portafolio-Projects\mis-collections\database\data`
- **WSL2 path**: `/home/rtrlpz/projects-portfolio/mis-collections/database/data`
- **Same physical files** — data persists across platform switches

### Backup Strategy (Optional)
```bash
# From either platform
docker exec postgres_collections pg_dump -U rtrlpz MIS_CollectionsDB > backup_$(date +%Y%m%d).sql
```

---

## Step 5: Troubleshooting Common Issues

| Issue | Solution |
|-------|----------|
| `docker: command not found` in WSL2 | Enable WSL Integration in Docker Desktop Settings → Resources |
| Port 5433 already in use | `docker compose down` on other platform first |
| Permission denied on `./data` | `sudo chown -R 999:999 database/data` from WSL2 |
| Slow file I/O | Store project in WSL2 filesystem (`/home/...`) not `/mnt/c/...` |
| Containers not visible | Run `docker context use default` in WSL2 |

---

## Step 6: Verification Checklist

After setup, verify all work:

- [ ] Docker Desktop shows "WSL 2 based engine" enabled
- [ ] WSL Integration enabled for your distro
- [ ] `docker ps` shows same containers from PowerShell and WSL2
- [ ] `./run_pipeline.sh --fresh` completes successfully from WSL2
- [ ] `.\run_pipeline.bat` completes successfully from PowerShell
- [ ] Data persists after `docker compose down` / `up -d` cycle
- [ ] Can connect via pgAdmin at `http://localhost:8081` from Windows browser
- [ ] Can connect via `psql -h localhost -p 5433 -U rtrlpz -d MIS_CollectionsDB` from both platforms

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                      Windows Host                             │
│  ┌──────────────────┐    ┌────────────────────────────────┐  │
│  │  Docker Desktop  │───▶│  WSL2 Backend (Ubuntu)         │  │
│  │  (GUI/CLI)       │    │  ┌──────────────────────────┐  │  │
│  └──────────────────┘    │  │  PostgreSQL Container    │  │  │
│         │                │  │  (postgres_collections)  │  │  │
│         │ localhost:5433 │  │  Port 5432 (internal)    │  │  │
│         ▼                │  │  Volume: ./data          │  │  │
│  ┌──────────────────┐    │  └──────────────────────────┘  │  │
│  │  PowerShell/CMD  │    └────────────────────────────────┘  │
│  │  run_pipeline.bat│         │                ▲              │
│  └──────────────────┘         │                │              │
└───────────────────────────────│────────────────┘              │
                                │                               │
                    ┌───────────┴───────────┐                   │
                    │   Shared Filesystem   │                   │
                    │ /home/rtrlpz/...      │                   │
                    │ (WSL2 native path)    │                   │
                    └───────────────────────┘                   │
```

---

## Migration from Current Setup

If currently running PostgreSQL in native Linux Docker:
1. `docker compose down -v` on Linux (backs up volumes)
2. Enable WSL2 backend per Step 1
3. `docker compose up -d` from Windows or WSL2
4. Run migrations: `bash migrate.sh --fresh`
5. Generate data: `./run_pipeline.sh --generate` or `.\run_pipeline.bat --generate`
6. Run ETL: `./run_pipeline.sh --etl` or `.\run_pipeline.bat --etl`

---

## References
- [Docker Desktop WSL2 Backend](https://docs.docker.com/desktop/wsl/)
- [WSL2 File System Performance](https://docs.microsoft.com/windows/wsl/compare-versions)
- Project docs: `docs/QUICKSTART.md`, `docs/TROUBLESHOOTING.md`