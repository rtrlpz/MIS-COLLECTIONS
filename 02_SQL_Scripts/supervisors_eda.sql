-- TABLA SUPERVISOR
SELECT * FROM supervisors;

-- Ver cuantos agentes tiene cada supervisor
SELECT
	s.name AS supervisor_name,
	s.team_name,
	COUNT(a.agent_id) AS total_agents
FROM supervisors s
JOIN agents a ON s.supervisor_id = a.supervisor_id
GROUP BY
	s.name,
	s.team_name
ORDER BY
	total_agents; --DESC;

-- Ver Total de Promesas (PTPs) por Region
SELECT
	s.region,
	COUNT(p.ptp_id) AS total_ptps_taken
FROM supervisors s
JOIN agents a ON s.supervisor_id = a.supervisor_id
JOIN  ptp_log p ON a.agent_id = p.agent_id
GROUP BY s.region
ORDER BY total_ptps_taken; --DESC;

-- Ver total de agentes por Region
SELECT
	s.region,
	COUNT(a.agent_id) AS total_agents_region
FROM supervisors s
JOIN agents a ON s.supervisor_id = a.supervisor_id
GROUP BY s.region
ORDER BY total_agents_region; -- DESC |

-- Ver total de promesas por equipo
SELECT
	s.region,
	s.team_name,
	COUNT(p.ptp_id) AS total_ptp_team
FROM supervisors s
JOIN agents a ON s.supervisor_id = a.supervisor_id
JOIN ptp_log p ON a.agent_id = p.agent_id
GROUP BY
	s.region,
	s.team_name
ORDER BY total_ptp_team; -- DESC |

-- Analizar la Tasa de Contacto Util (RPC RATE) por Region | Esta consulta mide la calidad de la actividad de contacto, enfocándose en qué tan a menudo el esfuerzo del discador resulta en una conversación útil (RPC).
SELECT
	s.region,
	SUM(d.calls_connected) AS total_connected,
	SUM(CASE WHEN d.rpc_flag = TRUE THEN 1 ELSE 0 END) as total_rpcs,
	-- Calcula el procentaje de RPC (RPC / Conectadas)
	CAST(SUM(CASE WHEN d.rpc_flag = TRUE THEN 1 ELSE 0 END) AS NUMERIC) * 100 /
		NULLIF(SUM(d.calls_connected), 0) AS rpc_rate_pct
FROM supervisors s
JOIN agents a ON s.supervisor_id = a.supervisor_id
JOIN dialer_interactions d on a.agent_id = d.agent_id
GROUP BY s.region
ORDER BY rpc_rate_pct DESC; -- RPC rate 60% let's make that randomly


-- Analizar el Monto Total Recaudado (Cures) por Equipo
SELECT
	s.team_name,
	COUNT(c.cure_id) AS total_cures,
	SUM(c.amount_paid) AS total_amount_paid
FROM supervisors s
JOIN agents a ON s.supervisor_id = a.supervisor_id
JOIN cures_log c ON a.agent_id = c.agent_id
GROUP BY s.team_name
ORDER BY total_amount_paid; --DECS -- Montos muy altos, acercarlos mas a la realidad

-- Productividad y Utilizacion de Agentes para evaluar la eficiencia del tiempo de los equipos
SELECT
	s.name AS supervisor_name,
	-- Calcula el promedio del porcentaje de utilizacion
	AVG(atl.utilization) AS avg_utilization_pct,
	-- Ver promedio de horas operativas
	AVG(atl.operational_hours) AS avg_operational_hours
FROM supervisors s
JOIN agents a ON s.supervisor_id = a.supervisor_id
JOIN agent_time_log atl ON a.agent_id = atl.agent_id
GROUP BY s.name
ORDER BY avg_utilization_pct; -- DESC -- Result range avg ut pct - 0.66008064516129032258 - 0.66683284457478005865 | avg operational hours 12.6063306451612903 - 12.5799706744868035 not okay op shouldn't exceed 9 hrs due to law and regulation


--  Analizar tasa de cumplimiento de PTP por equipo
SELECT
	s.team_name,
	COUNT(p.ptp_id) AS total_ptps_taken,
	SUM(CASE WHEN p.status = 'Kept' THEN 1 ELSE 0 END) AS total_kepts_ptps,
	-- Calcula porcentaje (kept /total taken)
	CAST(SUM(CASE WHEN p.status = 'Kept' THEN 1 ELSE 0 END) AS NUMERIC) * 100 /
		NULLIF(COUNT(p.ptp_id), 0) AS ptp_kept_rate_pct
FROM supervisors s
JOIN agents a ON s.superviSor_id = a.supervisor_id
JOIN ptp_log p ON a.agent_id = p.agent_id
GROUP BY s.team_name
ORDER BY ptp_kept_rate_pct; -- DESC -- kept promises range - (4.9917149958574979, 5.4102472232174848)

-- Calcula el porcentaje de recaudo (Cures) respecto al Balance Total por Equipo
SELECT
	s.team_name,
	-- 1. Balance Total (Mora/Activo) Manejado por equipo
	SUM(CASE WHEN a.status IN ('Activo', 'Mora') THEN a.balance ELSE 0 END) AS total_manage_balance,
	-- 2. Monto total recaudado por equipo
	(SELECT SUM(c.amount_paid)
	FROM cures_log c
	JOIN agents sub_a ON c.agent_id = sub_a.agent_id
	WHERE  sub_a.supervisor_id = s.supervisor_id) AS total_cures_amount,

	-- 3. Porcentaje de curas respecto al balance
	CAST((SELECT SUM(c.amount_paid)
		FROM cures_log c
		JOIN agents sub_a ON c.agent_id = sub_a.agent_id
		WHERE sub_a.supervisor_id = s.supervisor_id) AS NUMERIC) * 100 /
	NULLIF(SUM(CASE WHEN a.status IN ('Activo', 'Mora') THEN a.balance ELSE 0 END), 0) AS cure_to_balance_pct
FROM supervisors s
JOIN agents a_main ON s.supervisor_id = a_main.supervisor_id
JOIN accounts a ON a_main.agent_id = a.account_id
GROUP BY s.supervisor_id, s.team_name
ORDER BY cure_to_balance_pct; --DESC -- This needs attention

-- Distribucion de cartera por riesgo y segmento
SELECT
	s.team_name,
	-- Score de riesgo promedio de los clientes gestionandos por el equipo
	AVG(cl.risk_score) AS avg_client_risk_score,

	-- Cuantifica la concentracion de clientes en segmentos de interes (ej. 'Premium')
	SUM(CASE WHEN cl.segment = 'Premium' THEN 1 ELSE 0 END) AS total_premium_clients,

	-- Cuantas cuentas de sus clientes estan en Mora
	SUM(CASE WHEN a.status = 'Mora' THEN 1 ELSE 0 END) AS total_accounts_in_mora
FROM supervisors s
JOIN agents a_main ON s.supervisor_id = a_main.supervisor_id
JOIN accounts a ON a_main.agent_id = a.account_id
JOIN clientes cl ON  a.client_id = cl.cliente_id
GROUP BY s.team_name
ORDER BY avg_client_risk_score; --DESC;

-- Analisa tiempo promedio (AHT) por equipo
SELECT s.team_name,
	-- Tiempo promedio de manejo de la llamada en segundos
	AVG(d.aht_seconds) AS avg_aht_seconds,
	-- Varianza o Desviacion Estandar para medir consistencia
	STDDEV(d.aht_seconds) AS stddev_aht
FROM supervisors s
JOIN agents a ON s.supervisor_id = a.supervisor_id
JOIN dialer_interactions d ON a.agent_id = d.agent_id
GROUP BY s.team_name
ORDER BY avg_aht_seconds DESC; -- Ranges avg_aht (303.3435189748644653, 298.2494432071269488) Ranges STDDEV (97.1914312059668918, 98.8319825740754355)
-- Interpretación: Un stddev_aht alto sugiere que las llamadas dentro de ese equipo son muy inconsistentes, lo cual puede indicar falta de estandarización o agentes inexpertos.

-- Calcula el promedio de PTPs tomadas por equipor por dia
SELECT
	s.team_name,
	COUNT(p.ptp_id) AS total_ptp_period,
	COUNT(DISTINCT p.date_of_interaction) AS total_days_active,
	-- PTPs promedio por dia de operacion del equipo
	CAST(COUNT(p.ptp_id) AS NUMERIC) / NULLIF(COUNT(DISTINCT p.date_of_interaction), 0) AS avg_ptps_per_day
FROM supervisors s
JOIN agents a ON s.supervisor_id = a.supervisor_id
JOIN ptp_log p ON  a.agent_id = p.agent_id
GROUP BY s.team_name
ORDER BY avg_ptps_per_day DESC;

-- Analiza la composicion de la cartera (cuentas) por tipo de producto y equipo
SELECT
	s.team_name,
	p.product_type,
	COUNT(a.account_id) AS total_accounts_in_teams,
	-- Porcentaje de ese producto dentro de la cartera total del equipo
	CAST(COUNT(a.account_id) AS NUMERIC) * 100 /
		SUM(COUNT(a.account_id)) OVER (PARTITION BY s.team_name) AS pecentage_of_team_portafolio
FROM supervisors s
JOIN agents a_main ON s.supervisor_id = a_main.supervisor_id
JOIN accounts a ON a_main.agent_id = a.account_id -- Asignacion de cuenta/agente
JOIN products p ON a.product_id = p.product_id
GROUP BY
	s.team_name,
	p.product_type
ORDER BY s.team_name, pecentage_of_team_portafolio DESC;

-- Calcula el Balance Promedio por cuenta Gestionada por Equipo
SELECT
	s.team_name,
	COUNT(a.account_id) AS total_account_managed,
	-- Balance promedio de las cuentas activas/en mora asignada al equipo
	AVG(a.balance) AS avg_managed_balance,
	-- Balance promedio de la cartera total (Para comparacion)
	(SELECT AVG(balance) FROM accounts WHERE status IN ('Activo', 'Mora')) AS overall_avg_balance
FROM supervisors s
JOIN agents a_main ON s.supervisor_id = a_main.supervisor_id
JOIN accounts a ON a_main.agent_id = a.account_id -- Asignacion de cuenta/agente
WHERE a.status IN ('Activo', 'Mora')
GROUP BY s.team_name
ORDER BY avg_managed_balance DESC;

-- Analiza el porcentaje de ceuntas en Mora por Producto y por region
SELECT
	s.region,
	p.product_type,
	COUNT(a.account_id) AS total_accounts,
	SUM(CASE WHEN a.status = 'Mora' THEN 1 ELSE 0 END) AS accounts_in_mora,
	-- Porcentaje de las cuentas en Mora dentro de ese tipo de producto/region
	CAST(SUM(CASE WHEN a.status = 'Mora' THEN 1 ELSE 0 END) AS NUMERIC) * 100 /
		NULLIF(COUNT(a.account_id), 0) AS default_rate_pct
FROM supervisors s
JOIN agents a_main ON s.supervisor_id = a_main.supervisor_id
JOIN accounts a ON a_main.agent_id = a.account_id
JOIN products p ON a.product_id = p.product_id
GROUP BY s.region, p.product_type
ORDER BY s.region, default_rate_pct DESC;

-- Monto Recaudado (cures) por segmento de clientes y supervisor
SELECT
	s.name AS supervisor_name,
	cl.segment,
	SUM(c.amount_paid) AS total_amount_paid
FROM supervisors s
JOIN agents a ON s.supervisor_id = a.supervisor_id
JOIN cures_log c ON a.agent_id = c.agent_id
JOIN accounts a_acc ON c.account_id = a_acc.account_id
JOIN clients cl ON a_acc.client_id = cl.client_id
GROUP BY s.name, cl.segment
ORDER BY s.name, total_amount_paid DESC;

-- Analisis de tendencias y estabilidad

-- Días Activos de Logro de PTPs y Promedio de PTPs por día de actividad, por Supervisor
SELECT
    s.name AS supervisor_name,
    COUNT(DISTINCT p.date_of_interaction) AS days_with_ptps, -- Días en que el equipo tomó al menos 1 PTP
    COUNT(p.ptp_id) AS total_ptps,
    -- PTPs promedio por día que hubo actividad de promesa
    CAST(COUNT(p.ptp_id) AS NUMERIC) / NULLIF(COUNT(DISTINCT p.date_of_interaction), 0) AS avg_ptps_per_active_day
FROM supervisors s
JOIN agents a ON s.supervisor_id = a.supervisor_id
JOIN ptp_log p ON a.agent_id = p.agent_id
GROUP BY s.name
ORDER BY avg_ptps_per_active_day DESC;

-- Consistencia en las Horas Operativas de los Equipos (Variación Diaria)
SELECT
    s.team_name,
    -- Horas operativas promedio del equipo
    AVG(atl.operational_hours) AS avg_operational_hours,
    -- Desviación Estándar para medir la consistencia diaria de esas horas
    STDDEV(atl.operational_hours) AS stddev_operational_hours
FROM supervisors s
JOIN agents a ON s.supervisor_id = a.supervisor_id
JOIN agent_time_log atl ON a.agent_id = atl.agent_id
GROUP BY s.team_name
ORDER BY stddev_operational_hours DESC;

-- 🔒 Análisis de Cumplimiento de Procesos

-- Tasa de Cumplimiento de Pagos Programados por Equipo/Región
SELECT
    s.team_name,
    COUNT(ps.schedule_id) AS total_payments_due,
    SUM(CASE WHEN ps.status = 'Paid' THEN 1 ELSE 0 END) AS payments_successfully_made,
    SUM(CASE WHEN ps.status = 'Overdue' THEN 1 ELSE 0 END) AS payments_missed,
    -- Calcula el porcentaje de pagos exitosos (Paid / Total Due)
    CAST(SUM(CASE WHEN ps.status = 'Paid' THEN 1 ELSE 0 END) AS NUMERIC) * 100 /
        NULLIF(COUNT(ps.schedule_id), 0) AS schedule_paid_rate_pct
FROM supervisors s
JOIN agents a_main ON s.supervisor_id = a_main.supervisor_id
JOIN accounts acc ON a_main.agent_id = acc.account_id -- Asignación de cuenta/agente
JOIN payment_schedule ps ON acc.account_id = ps.account_id
GROUP BY s.team_name
ORDER BY schedule_paid_rate_pct DESC;

-- Número de Cuentas en Mora por Periodo de Gracia y Región
SELECT
    s.region,
    p.grace_period_days,
    COUNT(a.account_id) AS total_accounts_in_mora
FROM supervisors s
JOIN agents a_main ON s.supervisor_id = a_main.supervisor_id
JOIN accounts a ON a_main.agent_id = a.account_id
JOIN products p ON a.product_id = p.product_id
WHERE a.status = 'Mora' -- Solo cuentas en mora
GROUP BY s.region, p.grace_period_days
ORDER BY s.region, total_accounts_in_mora DESC;

-- 💲 Análisis Final: Costo de Recaudo por Supervisor
-- Calcula el Monto Recaudado por Hora Operativa, por Supervisor
SELECT
    s.name AS supervisor_name,

    -- 1. Horas Operativas Totales del Equipo
    SUM(atl.operational_hours) AS total_operational_hours,

    -- 2. Monto Total Recaudado (Cures) por el Equipo
    (SELECT SUM(c.amount_paid)
     FROM cures_log c
     JOIN agents sub_a ON c.agent_id = sub_a.agent_id
     WHERE sub_a.supervisor_id = s.supervisor_id) AS total_amount_cured,

    -- 3. Monto Recaudado por Hora Operativa (El KPI de Eficiencia)
    CAST((SELECT SUM(c.amount_paid)
          FROM cures_log c
          JOIN agents sub_a ON c.agent_id = sub_a.agent_id
          WHERE sub_a.supervisor_id = s.supervisor_id) AS NUMERIC) /
        NULLIF(SUM(atl.operational_hours), 0) AS amount_cured_per_hour

FROM supervisors s
JOIN agents a ON s.supervisor_id = a.supervisor_id
JOIN agent_time_log atl ON a.agent_id = atl.agent_id
GROUP BY s.supervisor_id, s.name
ORDER BY amount_cured_per_hour DESC;


-- 🔬 Análisis de Calidad y Rendimiento Cruzado
-- Calcula un Índice Ponderado de Eficiencia Financiera por Supervisor
SELECT
    s.name AS supervisor_name,

    -- Tasa de Recaudo por Hora Operativa (Ya calculada)
    (SELECT CAST(SUM(c.amount_paid) AS NUMERIC)
     FROM cures_log c
     JOIN agents sub_a ON c.agent_id = sub_a.agent_id
     WHERE sub_a.supervisor_id = s.supervisor_id) /
        NULLIF(SUM(atl.operational_hours), 0) AS amount_cured_per_hour,

    -- Tasa de RPC (Conversión) Promedio del equipo
    CAST(SUM(CASE WHEN d.rpc_flag = TRUE THEN 1 ELSE 0 END) AS NUMERIC) * 100 /
        NULLIF(SUM(d.calls_connected), 0) AS rpc_rate_pct,

    -- KPI Final: Multiplicar el Recaudo/Hora por la Tasa de RPC
    ( (SELECT CAST(SUM(c.amount_paid) AS NUMERIC)
       FROM cures_log c
       JOIN agents sub_a ON c.agent_id = sub_a.agent_id
       WHERE sub_a.supervisor_id = s.supervisor_id) /
      NULLIF(SUM(atl.operational_hours), 0) )
    * ( CAST(SUM(CASE WHEN d.rpc_flag = TRUE THEN 1 ELSE 0 END) AS NUMERIC) * 100 /
      NULLIF(SUM(d.calls_connected), 0) ) AS financial_efficiency_index

FROM supervisors s
JOIN agents a ON s.supervisor_id = a.supervisor_id
JOIN agent_time_log atl ON a.agent_id = atl.agent_id
JOIN dialer_interactions d ON a.agent_id = d.agent_id
GROUP BY s.supervisor_id, s.name
ORDER BY financial_efficiency_index DESC;

-- Identificar Cuentas en Mora SIN RPC (Contactos Útiles) en el período
SELECT
    s.team_name,
    COUNT(DISTINCT a.account_id) AS total_mora_accounts,
    COUNT(DISTINCT a.account_id) FILTER (WHERE d.rpc_flag IS NULL) AS mora_sin_rpc_count
FROM supervisors s
JOIN agents ag ON s.supervisor_id = ag.supervisor_id
JOIN accounts a ON ag.agent_id = a.account_id -- Asignación
LEFT JOIN dialer_interactions d ON a.account_id = d.account_id
    AND d.rpc_flag = TRUE -- Solo unimos RPCs
WHERE a.status = 'Mora'
GROUP BY s.team_name
ORDER BY mora_sin_rpc_count DESC;

-- Ratio de Recaudo por Promesa Tomada (Calidad de Negociación)
SELECT
    s.team_name,
    SUM(p.amount_promised) AS total_amount_promised,
    (SELECT SUM(c.amount_paid)
     FROM cures_log c
     JOIN agents sub_a ON c.agent_id = sub_a.agent_id
     WHERE sub_a.supervisor_id = s.supervisor_id) AS total_amount_cured,

    -- Ratio: Cures (Recaudo) / PTPs (Esfuerzo)
    (SELECT SUM(c.amount_paid)
     FROM cures_log c
     JOIN agents sub_a ON c.agent_id = sub_a.agent_id
     WHERE sub_a.supervisor_id = s.supervisor_id)
    / NULLIF(SUM(p.amount_promised), 0) AS cure_to_promise_ratio

FROM supervisors s
JOIN agents a ON s.supervisor_id = a.supervisor_id
JOIN ptp_log p ON a.agent_id = p.agent_id
GROUP BY s.supervisor_id, s.team_name
ORDER BY cure_to_promise_ratio DESC;


-- 📈 Análisis Final: Dispersión y Benchmarking

-- Identifica el Mejor y el Peor Equipo por Tasa de Cumplimiento de PTPs
WITH PTP_Fulfillment AS (
    SELECT
        s.team_name,
        CAST(SUM(CASE WHEN p.status = 'Kept' THEN 1 ELSE 0 END) AS NUMERIC) * 100 /
            NULLIF(COUNT(p.ptp_id), 0) AS ptp_kept_rate_pct
    FROM supervisors s
    JOIN agents a ON s.supervisor_id = a.supervisor_id
    JOIN ptp_log p ON a.agent_id = p.agent_id
    GROUP BY s.team_name
)
SELECT
    'Mejor Equipo' AS performance_level,
    team_name,
    ptp_kept_rate_pct
FROM PTP_Fulfillment
ORDER BY ptp_kept_rate_pct DESC
LIMIT 1

UNION ALL

SELECT
    'Peor Equipo' AS performance_level,
    team_name,
    ptp_kept_rate_pct
FROM PTP_Fulfillment
ORDER BY ptp_kept_rate_pct ASC
LIMIT 1;


-- Desviación del Monto Recaudado de la Media Operacional
WITH Recaudo AS (
    SELECT
        s.team_name,
        (SELECT SUM(c.amount_paid)
         FROM cures_log c
         JOIN agents sub_a ON c.agent_id = sub_a.agent_id
         WHERE sub_a.supervisor_id = s.supervisor_id) AS total_amount_cured
    FROM supervisors s
    GROUP BY s.supervisor_id, s.team_name
)
SELECT
    r.team_name,
    r.total_amount_cured,
    -- Calcula la diferencia de la media general
    r.total_amount_cured - AVG(r.total_amount_cured) OVER () AS deviation_from_average
FROM Recaudo r
ORDER BY deviation_from_average DESC;


-- Ver registros de la tabla agentes
SELECT * FROM agents;

-- Ver registros de la tabla clientes
SELECT * FROM clients;

-- Ver registros de la tabla productos
SELECT * FROM products;

-- Ver registros de la tabla cuentas
SELECT * from accounts;

-- Ver registros de la tabla pagos agendados
SELECT * FROM payment_schedule;
s
-- Ver registros de la tabla iteracciones del dialer
SELECT * FROM dialer_interactions;

-- Ver registros de la tabla ptp
SELECT * FROM ptp_log;

-- Ver registros de la tabla curas
SELECT * FROM cures_log;

-- Ver registros de la tabla agente login time
SELECT * FROM agent_time_log;
