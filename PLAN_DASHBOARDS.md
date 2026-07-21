# PLAN DE IMPLEMENTACIÓN: 9 DASHBOARDS DE COLLECTIONS

**Fecha:** 2026-07-21
**Objetivo:** Preparar generator, schema y DAX para 9 dashboards de collections
**Consolidación:** Executive Collections + Executive Scorecard fusionados en uno solo

---

## RESUMEN DE DASHBOARDS

| # | Dashboard | Cobertura | Estado | Notas |
|---|-----------|-----------|--------|-------|
| 1 | Executive Collections | 94% | ✅ Listo | Fusionado con Scorecard. Incluir risk heat map + cost per account |
| 2 | Agent Performance | 78% | ⚠️ Necesita measures nuevas | RPC%, KP%, Cure, Util, AHT, Composite Score, WoW trends |
| 3 | Dialer Performance | 57% | ⚠️ Necesita generator + measures | Call volume, answer rate, RPC dialer-only, AHT by channel |
| 4 | Portfolio Management | 80% | ⚠️ Necesita measures nuevas | Arrears waterfall, delinquency bands, DPD migration Sankey |
| 5 | Operations Command Center | 38% | ⚠️ Versión limitada | Calls Offered/Answered, AHT, Occupancy, Agent Login/Logout |
| 6 | Credit Risk | 42% | ⚠️ Necesita generator + measures | Delinquency by segment, Roll rates, Cure rates, Credit utilization |
| 7 | Financial Recovery | 60% | ⚠️ Necesita generator + measures | Recovery vs cost, Write-offs, Cost-to-collect, Net recovery |
| 8 | Vintage Analysis | 0% | ❌ Necesita generator overhaul | DPD by account age, Vintage curves, Cure by vintage month |
| 9 | Roll Rate Analysis | 20% | ⚠️ Necesita measures nuevas | Sankey (prev→curr), Skip/deteriorate rates, Stuck 90+ |

**Excluidos (6):** Executive Scorecard, WFM, QA, Compliance, Customer Experience, Recovery Forecast

---

## ESTADO ACTUAL DE DAX

### Lo que YA existe (207 medidas en CSV)
- `_Goals & Targets`: 31 (7 goals + 7 gaps + 7 status + 7 color + 2 calculated tables + 1 selected goal)
- `_Outreach & Activity`: 20
- `_Promise & Conversion`: 13
- `_Recovery & Collection`: 16
- `_Portfolio Health`: 20
- `_Time Intelligence`: 36 (MoM measures solamente)

### Lo que está DOCUMENTADO pero NO en el CSV (91 medidas)
- WoW (Week-over-Week): 21 medidas (7 Prior Week + 7 WoW Change + 7 WoW %)
- DoD (Day-over-Day): 21 medidas (7 Prior Day + 7 DoD Change + 7 DoD %)
- YoY (Year-over-Year): 21 medidas (7 Prior Year + 7 YoY Change + 7 YoY %)
- OTC (Overall-to-Current): 21 medidas (7 Overall Avg + 7 OTC Change + 7 OTC %)
- Total: 84 medidas + 7 faltantes de MoM = 91

### Lo que FALTA para los 9 dashboards (~25 medidas nuevas)
- Roll Rate completos (cure rates, improvement rates, skip paths)
- Financial Recovery (Net Recovery, Cost to Collect, Write-offs)
- Credit Risk (Credit Utilization, Risk Segmentation)
- Vintage/Cohort (Account Vintage Month, Months on Book)
- Composite Score para Agent Performance

### TOTAL FINAL: ~323 medidas DAX
- 207 existentes (sin cambios)
- 91 documentadas pero no en CSV (agregar al CSV)
- 25 nuevas para dashboards (agregar al CSV)

---

## FASE 1: GENERATOR (config.py + data_generator_v7.py)

### 1.1 Nuevos parámetros en config.py

```python
# Agregar a CFG dict:
"open_date_spread_months": (12, 24),   # Vintage/Cohort analysis
"months": 12,                          # Full year data (default)

# Channel mix (para distinguir Dialer vs FICO/SMS)
"channel_mix": {
    "Dialer": 0.85,
    "FICO": 0.10,
    "SMS": 0.05,
},

# Write-off modeling
"write_off": {
    "enabled": True,
    "threshold_dpd": 180,
    "monthly_rate": 0.02,
},

# Agent cost (para Financial Recovery)
"agent_cost_per_hour": (18, 28),

# Modificar PRODUCT_CFG para incluir credit_limit:
"Tarjeta": { ..., "credit_limit_range": (1000, 50000) },
"Prestamo": { ..., "credit_limit_range": (3000, 80000) },
"Hipoteca": { ..., "credit_limit_range": (50000, 500000) },

# Income bracket para Dim_Clients
"income_bracket": {
    "Low": 0.35,
    "Mid": 0.45,
    "High": 0.20,
},
```

### 1.2 Cambios en data_generator_v7.py

| # | Sección | Cambio | Líneas |
|---|---------|--------|--------|
| G1 | Dim_Accounts | `open_date` usa `CFG["open_date_spread_months"]` | ~310 |
| G2 | Dim_Agents | Agregar `cost_per_hour` | ~230 |
| G3 | Dim_Accounts | Agregar `credit_limit` desde PRODUCT_CFG | ~320 |
| G4 | Dim_Clients | Agregar `income_bracket` | ~295 |
| G5 | Fact_Interactions | Agregar `channel` columna | ~650 |
| G6 | Mora Aging | Agregar lógica de write-off | ~770 |
| G7 | Dim_Calendar | Expandir a 13 meses | ~137 |
| G8 | Dim_Supervisors | Agregar `hire_date` | ~210 |
| G9 | Dim_Agents | Agregar `hire_date` | ~230 |

### 1.3 Nueva tabla: Fact_Writeoffs

```python
# Después de Mora Aging (~línea 770)
if state["dpd"] > CFG["write_off"]["threshold_dpd"]:
    if random.random() < CFG["write_off"]["monthly_rate"]:
        fact_writeoffs.append({...})
```

---

## FASE 2: DATABASE SCHEMA (Migrations)

### 2.1 Nuevas columnas en tablas existentes

| Tabla | Columna | Tipo | Justificación |
|-------|---------|------|---------------|
| `dim_agents` | `hire_date` | DATE | Tenure analysis |
| `dim_agents` | `cost_per_hour` | DECIMAL(6,2) | Financial Recovery |
| `dim_supervisors` | `hire_date` | DATE | Supervisor tenure |
| `dim_accounts` | `credit_limit` | DECIMAL(12,2) | Credit Risk |
| `dim_clients` | `income_bracket` | VARCHAR(20) | Credit Risk segmentation |
| `fact_interactions` | `channel` | VARCHAR(20) | RPC% correcto (excluir FICO/SMS) |
| `fact_eom_snapshot` | `prev_dpd_bucket` | VARCHAR(20) | DPD Migration Sankey |
| `fact_ptp_log` | `resolved_date` | DATE | Time-to-resolution |

### 2.2 Nuevas tablas

| Tabla | Propósito |
|-------|-----------|
| `fact_writeoffs` | Eventos de write-off (writeoff_id, writeoff_date, account_id FK, writeoff_amount, reason) |

### 2.3 Nuevas vistas

| Vista | Propósito |
|-------|-----------|
| `v_dpd_migration_matrix` | Sankey visual (prev_bucket → current_bucket) |
| `v_weekly_agent_summary` | WoW measures (agregación semanal) |
| `v_rls_supervisor_map` | Row-Level Security |

### 2.4 Vistas modificadas

| Vista | Columnas agregadas |
|-------|-------------------|
| `v_monthly_summary` | total_arrears, total_balance, mora_rate_pct, bb_conversion, cures_per_tht |
| `v_agent_scorecards` | coaching_flag, previous_month_composite, score_trend |
| `v_handle_time_metrics` | pct_rpc_within_sla, pct_nonrpc_within_sla |

### 2.5 Nuevos constraints

| Tabla | Constraint | Regla |
|-------|-----------|-------|
| `fact_eom_snapshot` | `chk_prev_dpd_bucket` | IN ('Current','1-30','31-60','61-90','90+') |
| `fact_interactions` | `chk_channel` | IN ('Dialer','FICO','SMS','Email','Branch') |
| `dim_agents` | `chk_hire_date` | hire_date <= CURRENT_DATE |
| `fact_writeoffs` | `chk_writeoff_amount` | writeoff_amount > 0 |

### 2.6 Nuevos indexes

| Tabla | Columna(s) | Tipo |
|-------|-----------|------|
| `fact_eom_snapshot` | `prev_dpd_bucket` | B-tree |
| `fact_interactions` | `channel` | B-tree |
| `fact_writeoffs` | `account_id` | B-tree |
| `fact_writeoffs` | `writeoff_date` | B-tree |
| `dim_agents` | `hire_date` | B-tree |
| `fact_eom_snapshot` | `(snapshot_date, account_id, dpd_bucket, arrears)` | Covering |

---

## FASE 3: DAX MEASURES (collections_dax_v2.csv)

### 3.1 Medidas existentes que NO necesitan cambios (207)

Todas las 207 medidas actuales siguen siendo válidas. Los strings hardcodeados ("Mora", "Kept", "Broken", "Agent_Cure", "Self_Cure", "Online", "Branch/ATM", "OFI", "1-30", etc.) coinciden con la salida del generator.

### 3.2 Medidas documentadas pero NO en CSV (91) — AGREGAR AL CSV

#### WoW (21 medidas) — Sección 7 del markdown
Promise Rate, KP Rate, ACW RPC, ACW Non-RPC, Capped KP/RPC Arrears, Cures/THT, Utilization × (Prior Week + WoW Change + WoW %)

#### DoD (21 medidas) — Sección 8 del markdown
Mismas 7 métricas × (Prior Day + DoD Change + DoD %)

#### YoY (21 medidas) — Sección 9 del markdown
Mismas 7 métricas × (Prior Year + YoY Change + YoY %)

#### OTC (21 medidas) — Sección 10 del markdown
Mismas 7 métricas × (Overall Avg + OTC Change + OTC %)

#### Faltantes de MoM (7 medidas) — Para completar las 36 del CSV
Verificar si Promise Rate MoM %, KP Rate MoM %, etc. ya existen en el CSV

### 3.3 Medidas NUEVAS para los 9 dashboards (~22)

#### Roll Rate Analysis (Dashboard 9) — 8 medidas
| Medida | Fórmula |
|--------|---------|
| `Roll Rate 30 to Current (Cure)` | DIVIDE(COUNT(prev=1-30, curr=Current), COUNT(prev=1-30)) |
| `Roll Rate 60 to 30 (Improve)` | DIVIDE(COUNT(prev=31-60, curr=1-30), COUNT(prev=31-60)) |
| `Roll Rate 90 to 60 (Improve)` | DIVIDE(COUNT(prev=61-90, curr=31-60), COUNT(prev=61-90)) |
| `Roll Rate 30 to 90 (Skip)` | DIVIDE(COUNT(prev=1-30, curr=61-90), COUNT(prev=1-30)) |
| `Roll Rate 30 to 90+ (Skip)` | DIVIDE(COUNT(prev=1-30, curr=90+), COUNT(prev=1-30)) |
| `Roll Rate 60 to 90+ (Deteriorate)` | DIVIDE(COUNT(prev=31-60, curr=90+), COUNT(prev=31-60)) |
| `Roll Rate Stuck 90+` | DIVIDE(COUNT(prev=90+, curr=90+), COUNT(prev=90+)) |
| `Overall Deterioration Rate` | DIVIDE(deteriorations, all_transitions) |

#### Financial Recovery (Dashboard 7) — 5 medidas
| Medida | Fórmula |
|--------|---------|
| `Write-off Amount` | SUM('Fact_Writeoffs'[writeoff_amount]) |
| `Write-off Count` | DISTINCTCOUNT('Fact_Writeoffs'[account_id]) |
| `Net Recovery` | [Total Recovery] - [Write-off Amount] |
| `Cost to Collect` | SUMX(AgentTime, operational_hours * cost_per_hour) |
| `Cost per Dollar Collected` | DIVIDE([Cost to Collect], [Total Recovery]) |

#### Credit Risk (Dashboard 6) — 3 medidas
| Medida | Fórmula |
|--------|---------|
| `Avg Credit Limit` | AVERAGE('Dim_Accounts'[credit_limit]) |
| `Credit Utilization %` | DIVIDE(Arrears, SUM(credit_limit)) |
| `Income Segment Distribution` | COUNT(VALUES('Dim_Clients'[income_bracket])) |

#### Vintage Analysis (Dashboard 8) — 2 medidas
| Medida | Fórmula |
|--------|---------|
| `Account Vintage Month` | FORMAT('Dim_Accounts'[open_date], "YYYY-MM") |
| `Months on Book` | DATEDIFF('Dim_Accounts'[open_date], MAX(snapshot_date), MONTH) |

#### Portfolio Management (Dashboard 4) — 1 medida
| Medida | Fórmula |
|--------|---------|
| `DPD Migration %` | DIVIDE(crossover_accounts, total_current) |

#### Agent Performance (Dashboard 2) — 2 medidas
| Medida | Fórmula |
|--------|---------|
| `Composite Score` | Weighted: RPC 25% + KP 25% + Cure 20% + Util 15% + AHT 15% |
| `Coaching Alert` | IF(WoW drops > thresholds, "Alert", "OK") |

#### Dialer Performance (Dashboard 3) — 1 medida
| Medida | Fórmula |
|--------|---------|
| `Outbound Calls Only` | CALCULATE([Total Calls], channel="Dialer") |

### 3.4 RESUMEN TOTAL DAX

| Categoría | Cantidad | Estado |
|-----------|----------|--------|
| Existentes en CSV | 207 | ✅ Sin cambios |
| Documentadas, no en CSV | 91 | ⚠️ Agregar al CSV |
| Nuevas para dashboards | 22 | 🆕 Agregar al CSV |
| **TOTAL FINAL** | **320** | |

---

## FASE 4: ARCHIVOS A MODIFICAR

| # | Archivo | Cambio | Prioridad |
|---|---------|--------|-----------|
| 1 | `data_sources/generators/config.py` | +8 parámetros nuevos, modificar PRODUCT_CFG | ALTA |
| 2 | `data_sources/generators/data_generator_v7.py` | 9 secciones modificadas + Fact_Writeoffs | ALTA |
| 3 | `database/migrations/001_create_tables.sql` | +8 columnas, +1 tabla nueva | ALTA |
| 4 | `database/migrations/002_kpi_views.sql` | +3 vistas modificadas, +3 vistas nuevas | ALTA |
| 5 | `database/migrations/003_constraints.sql` | +4-8 constraints | MEDIA |
| 6 | `database/migrations/005_indexes.sql` | +6 indexes | MEDIA |
| 7 | `database/migrations/006_comments.sql` | Comments para nuevas columnas/tablas | BAJA |
| 8 | `database/seeds/002_dim_calendar.sql` | Expandir a 13 meses | ALTA |
| 9 | `dashboards/assets/dax/collections_dax_v2.csv` | +113 medidas (91 doc + 22 nuevas) | ALTA |
| 10 | `dashboards/assets/docs/dax_measures_dictionary_v2.md` | Documentación de 113 nuevas medidas | MEDIA |
| 11 | `test/conftest.py` | Actualizar GENERATOR_ROW_COUNTS + METRIC_RANGES | MEDIA |
| 12 | `test/qa_validation.py` | Tests para nuevas columnas/tablas | MEDIA |
| 13 | `CLAUDE.md` | Actualizar row counts, DAX total, nuevos parámetros | MEDIA |

---

## FASE 5: ORDEN DE EJECUCIÓN

```
PASO  1: config.py (agregar nuevos parámetros)
PASO  2: data_generator_v7.py (implementar G1-G9)
PASO  3: Generar nuevos CSVs (python data_generator_v7.py --months 12)
PASO  4: 002_dim_calendar.sql (expandir seed a 13 meses)
PASO  5: 001_create_tables.sql (nuevas columnas + tabla Fact_Writeoffs)
PASO  6: 002_kpi_views.sql (vistas modificadas + nuevas)
PASO  7: 003_constraints.sql (nuevos constraints)
PASO  8: 005_indexes.sql (nuevos indexes)
PASO  9: 006_comments.sql (comments)
PASO 10: collections_dax_v2.csv (+113 medidas)
PASO 11: dax_measures_dictionary_v2.md (documentación)
PASO 12: conftest.py + qa_validation.py (tests actualizados)
PASO 13: CLAUDE.md (actualizar)
PASO 14: ETL (cargar nuevos datos a PostgreSQL)
PASO 15: Ejecutar tests (python -m pytest test/ -v)
```

---

## DECISIONES PENDIENTES

**¿Los 12 meses de datos deben empezar en Enero 2025 o Octubre 2024?**
- **Enero 2025:** 12 meses (Jan-Dec 2025). No YoY (necesitarías 2024).
- **Octubre 2024:** Oct 2024 - Sep 2025. YoY parcial disponible.

Recomendación: **Enero 2025** (cleaner para un portfolio project).
