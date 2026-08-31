# LEGACY — Metrics & Visuals Catalog (v1, May 2026)

> **ARCHIVED (2026-08-31).** Superseded planning artifact recovered from the deleted
> `feature/powerbi-dashboard` branch (commit `e2cd958`, 2026-05-24). This catalog was
> built around the **old 5-page dashboard structure** and an early **74-measure** DAX set.
> Current dashboard design is the **9-page wireframe** in `docs/powerbi/dashboard_blueprint.md`
> (148 active measures + `_Time Intelligence` Calculation Group). Kept for historical reference
> only — do not treat the page numbers, DAX counts, or targets below as current.

---

# MSI Collections — Metrics & Visuals Catalog

---

## 📊 Columnas / Barras (agrupadas o apiladas)
> Comparaciones de volúmenes y distribuciones.

| # | Métrica | Nivel | Página |
|---|---|---|---|
| 1 | Calls Attempted / Calls Connected / Total Calls Attempted | Agente / Portfolio | 2, 3 |
| 2 | Total RPCs / Non-RPC Connections | Agente / Portfolio | 2, 3 |
| 3 | Total RPC Arrears | Agente / Portfolio | 2, 5 |
| 4 | Amount Promised / Capped KP $ | Agente / Portfolio | 2, 5 |
| 5 | Total Amount Paid / Cured Amounts / Non-Cured Amount | Agente / Portfolio | 2, 4 |
| 6 | Agent-Assisted Cures $ / Self-Cures $ | Agente / Portfolio | 2, 4 |
| 7 | Agent Cure Count / Self-Cure Count | Agente / Portfolio | 2, 4 |
| 8 | Accounts DPD buckets (1–30, 31–60, 61–90, 90+) | Cuenta / Portfolio | 1, 4 |
| 9 | Portfolio Total Balance / Portfolio Total Arrears | Portfolio | 4 |
| 10 | Cured Amount Prior Month / Total Cures Prior Month | Portfolio | 4 |
| 11 | Portfolio Balance Prior Month | Portfolio | 4 |

---

## 📈 Líneas (tendencias temporales)
> Evolución de tasas y porcentajes.

| # | Métrica | Nivel | Página |
|---|---|---|---|
| 1 | Connection Rate % / RPC % | Agente / Portfolio | 1, 2 |
| 2 | KP % / Broken Rate % / PTP % | Agente / Portfolio | 1, 2, 5 |
| 3 | KP % Prior Month / KP % MoM Change | Portfolio | 4 |
| 4 | RPC % Prior Month | Portfolio | 4 |
| 5 | BB Conversion Rate / BB Conversion Prior Month | Portfolio | 4, 5 |
| 6 | Cures MoM Change | Portfolio | 4 |
| 7 | Cured Amount MoM % | Portfolio | 4 |
| 8 | Mora Rate % / Mora Rate Prior Month / Mora Rate MoM Change | Portfolio | 4 |
| 9 | True Occupancy % / THT Alignment % | Agente / Portfolio | 2, 3 |

---

## 🥧 Pie / Dona (distribuciones porcentuales)
> Proporciones y participación relativa.

| # | Métrica | Nivel | Página |
|---|---|---|---|
| 1 | Self-Cure Rate % | Portfolio | 4 |
| 2 | Online Payments % / Branch ATM Payments % / OFI Payments % | Portfolio | 4 |
| 3 | Expenses por categoría / proveedor | Portfolio | — |

---

## 🎯 Gauge Charts
> Indicadores de cumplimiento frente a meta.

| # | Métrica | Target Sugerido | Página |
|---|---|---|---|
| 1 | BB Conversion Rate | ≥40% | 2, 5 |
| 2 | Capped KP / RPC Arrears | TBD | 5 |
| 3 | Collection Efficiency % | ≥90% | 4 |
| 4 | Arrears / Balance % | <20% | 4 |

---

## 📋 KPI Cards
> Valores únicos, promedios o totales.

| # | Métrica | Unidad | Página |
|---|---|---|---|
| 1 | Avg AHT RPC / Non-RPC | segundos | 2 |
| 2 | Avg ACW RPC / Non-RPC | segundos | 2 |
| 3 | Avg Utilization % | % | 1, 2 |
| 4 | Agents Below Util Target | count | 2 |
| 5 | Total Operational Hours / Total THT Hours | horas | 2, 3 |
| 6 | Evaluated PTPs | count | 5 |
| 7 | Total Accounts | count | 4 |
| 8 | Avg Balance per Account | $ | 4 |
| 9 | Avg Arrears per Mora Account | $ | 4 |

---

## 🔎 Dispersión (Scatter)
> Relación entre productividad y tiempo.

| # | Métrica | Eje X | Eje Y | Página |
|---|---|---|---|---|
| 1 | RPC per Op Hr / RPC per THT Hr | Op Hr / THT Hr | RPC Count | 3 |
| 2 | Cures per THT / Cures per Op Hr | THT Hr / Op Hr | Cure Count | 3 |

---

## 🌊 Área (YTD / Rolling)
> Métricas acumuladas o promedios móviles.

| # | Métrica | Ventana | Página |
|---|---|---|---|
| 1 | Cured Amount YTD | YTD (enero a la fecha) | 4 |
| 2 | KP % YTD | YTD | 4 |
| 3 | Rolling 3M KP % | 3 meses móviles | 4, 5 |

---

## 📑 Tablas / Matrices
> Detalle granular y comparaciones lado a lado.

| # | Contenido | Fuente | Página |
|---|---|---|---|
| 1 | Calls Attempted / Connected por agente / campaña | Fact_Interactions | 2, 3 |
| 2 | Avg AHT / ACW por agente | Fact_Interactions | 2 |
| 3 | Promesas (Kept, Broken, Pending) por cuenta | Fact_PTP_Log | 5 |
| 4 | Amount Promised vs RPC Arrears por cliente | Fact_PTP_Log | 5 |
| 5 | Pagos por método (Online, Branch ATM, OFI) con monto y conteo | Fact_Payments | 4 |
| 6 | Agent-Assisted vs Self-Cures por agente | Fact_Payments | 2, 4 |
| 7 | Horas operativas y THT por agente | Fact_Agent_Time_Log | 2, 3 |
| 8 | Utilización por agente | Fact_Agent_Time_Log | 2 |
| 9 | Portfolio balances y arrears por snapshot | Fact_EOM_Snapshot | 4 |
| 10 | Accounts in Mora y buckets DPD con detalle de cuentas | Fact_EOM_Snapshot | 4 |

---

## ⚖️ Híbridas (KPI o gráfico según detalle)

| Métrica | Como KPI | Como Gráfico |
|---|---|---|
| Capped KP $ | Total portfolio | Barras por agente / canal |
| Total Cures | Valor global | Columnas por mes / canal |
| Self-Cure vs Agent-Cure | Proporción (%) | Columnas en el tiempo |
| MoM Change (KP%, Cures, Mora Rate) | Delta puntual | Línea de evolución |

---

## Resumen

| Tipo Visual | Cantidad |
|---|---|
| Columnas / Barras | ~30 métricas |
| Líneas | ~20 métricas |
| Pie / Dona | ~5 métricas |
| Gauge | ~5 métricas |
| KPI Cards | ~10 métricas |
| Dispersión | ~5 métricas |
| Área (YTD / Rolling) | ~3 métricas |
| Tablas / Matrices | ~10 bloques |
| Híbridas | ~5 métricas |
| **Total** | **~93 métricas** |
