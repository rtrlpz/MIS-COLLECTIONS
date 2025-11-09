
# - Notas:

## - Archivos y sus campos claves:

1. Supervisors.csv - supervisor_id, supervisor_name, team_name
2. agents.csv - agent_id, agent_name, supervisor_id
3. clientes.csv - cliente_id (PK), segment, risk_score
4. Productos.csv - product_id (PK), product_name, product_type, interest_rate, grace_period_days, default_min_payment_rule
5. accounts.csv - account_id (PK), client_id (FK), product_id (FK), open_date, due_date, min_payment, balance, status (activo, mora, cerrado)
6. agent_time_log.csv - time_id, date, agent_id (FK), login_time, logout_time, break_minutes, operational_hours, tht_hours, schedule_hours
7. dialer_interactions.csv -interaction_id (PK), date, agent_id (FK) -> agents, account_id (FK) -> accounts, rpc_flag(1 si fue RPC), aht_seconds
8. ptp_log.csv - ptp_id (PK), date_of_interaction, agent_id (FK), account_id(FK), promise_due_date, status (pending, kept, broken)
9. cures_log.csv - cure_id (PK), date_of_payment, agent_id (FK), account_id (FK), amount_paid00
10. payment_scheduled.csv - schedule_id (PK), account_id (FK), due_date, expected_amount, status

- Tip: Menciona en la entrevista que en un entorno real usarías un Schema (Esquema), por ejemplo, Collections.Clients, para organizar las tablas y permisos.

🔗 Relaciones entre tablas
- Clients ↔ Accounts: 1:N (un cliente puede tener varias cuentas).
- Clients ↔ Accounts ↔ Products: cartera completa con reglas de producto.
- Accounts ↔ PTP Log: 1:N (una cuenta puede tener varias promesas).
- - Accounts ↔ Payments Schedule ↔ Cures Log: simula pagos esperados vs. pagos reales.
- Accounts ↔ Cures Log: 1:N (una cuenta puede tener varios pagos).
- Agents ↔ Dialer Interactions: 1:N (un agente realiza muchas llamadas).
- Agents ↔ PTP Log: 1:N (un agente registra muchas promesas).
- Agents ↔ Cures Log: 1:N (un agente registra muchos pagos).
- Agents ↔ Agent Time Log: 1:N (un agente tiene registros diarios de tiempo).
- Dialer Interactions ↔ Accounts: cada interacción se vincula a una cuenta.

# Lógica de negocio con clientes y cuentas

## Generación de cartera
- Cada cliente tiene 1–5 cuentas (mayoría 1–2).
- Cada cuenta tiene fecha de apertura, saldo, pago mínimo, fecha de vencimiento. 
## Interacciones
- Las llamadas (dialer_interactions) se vinculan a cuentas.
- Si es RPC, puede generar una promesa (ptp_log).
## Promesas
- Se registran contra una cuenta específica.
- Se evalúan como Kept o Broken según pagos en cures_log.
## Pagos (Cures)
- Se registran contra cuentas.
- Si cumplen la promesa en fecha y monto → Kept.
- Si no → Broken.
## Reporte final
- Se agregan métricas por agente y mes.
- Se calculan KPIs como KP%, PTP%, Cures/THT, Capped KP/RPC Arrears.

Es crucial cargar las tablas en este orden para satisfacer las restricciones de claves foráneas:

supervisors.csv

agents.csv

clients.csv

products.csv

accounts.csv

payment_schedule.csv (Depende de accounts)

dialer_interactions.csv (Depende de agents, accounts)

ptp_log.csv (Depende de agents, accounts)

cures_log.csv (Depende de agents, accounts)

agent_time_log.csv (Depende de agents)