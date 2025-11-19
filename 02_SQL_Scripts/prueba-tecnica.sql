-- ///// FUNDAMENTOS DE CARTERA Y NEGOCIO ///// --

-- 1. Calcula el Total de balance en 'Mora' por segment de cliente.

-- 2. Lista los 10 clientes con el mayor balance total en sus cuentas.

-- 3. Crea una vista que muestre KPIs claves: Total Cured Amount y Promedio amount_promised (PTP) MTD.

-- 4. Une agents y agent_time_log para calcular el Total operational_hours por supervisor.

-- 5. Calcula el Promedio del risk_score de clientes en Mora por product_type.

-- 6. Lista los account_id con status 'Overdue' en payment_schedule.

-- 7. Lista el account_id y amount_promised de PTPs con status 'Broken'.

-- 8. Calcula la Tasa de Cumplimiento de PTPs (PTP%): # of Kept / Total PTPs (mensual).

-- 9. Crea un índice para optimizar consultas de desempeño por agent_id en dialer_interactions.

-- 10. Crea un procedimiento almacenado para generar el resumen de Total_RPCs por supervisor.



-- ///// FUNDAMENTOS DE CARTERA Y NEGOCIO ///// --

-- 11.	Calcula el Total de Cures (amount_paid) por supervisor para el mes actual.

-- 12.	Lista a todos los agentes con un Total_RPCs menor que el promedio del equipo.

-- 13.	Calcula la eficiencia del tiempo para cada agente: tht_hours sobre operational_hours (utilization) para la fecha de hoy.

-- 14.	Calcula el Promedio de AHT (segundos) para interacciones RPC (rpc_flag = TRUE) para cada agente.

-- 15.	Crea un ranking (usando RANK()) de agentes basado en el Total_Cured_Amount para el mes, mostrando el nombre del supervisor.

-- 16.	Identifica el supervisor con el peor PTP% (Tasa de Cumplimiento de PTPs).

-- 17.	Calcula la relación de llamadas conectadas vs intentadas (calls_connected / calls_attempted) por agente.

-- 18.	Lista los 5 product_name con el mayor balance total de cuentas en estado 'Mora'.

-- 19.	Calcula el porcentaje de cuentas en estado 'Cerrado' respecto al total de cuentas, agrupado por product_type.

-- 20.	Identifica qué segment de cliente tiene el risk_score promedio más alto entre todas las cuentas 'Activo'.

-- 21.	Escribe una consulta para obtener el balance promedio de las cuentas que tienen una due_date posterior a hoy.

-- 22.	Encuentra la cantidad de cuentas que han tenido más de 3 interacciones de discador (dialer_interactions) en la última semana.

-- 23.	Crea una vista que calcule el Score de Contacto de los agentes: Total_RPCs dividido por Total_Connections (la métrica RPC%).

-- 24.	Escribe una consulta para encontrar las cuentas que tienen PTPs con status='Broken' y que actualmente tienen status='Mora' en la tabla accounts.

-- 25.	Crea un procedimiento almacenado para actualizar el campo status en payment_schedule a 'Overdue' si la due_date es anterior a la fecha de hoy.

-- 26.	Diseña una consulta para calcular el monto promedio prometido (amount_promised) por PTP, segmentado por rango de risk_score del cliente.

-- 27.	Identifica los agentes que han trabajado con cuentas que tienen un min_payment superior al promedio de todas las cuentas.

-- 28.	Escribe una consulta para calcular el ACW Promedio (segundos) para cada agente, solo incluyendo las interacciones con calls_connected mayor a 0.

-- 29.	Crea una tabla temporal o CTE que muestre el Total de Cures y el Total de PTPs del día anterior para todos los agentes.

-- 30.	¿Qué índice crearías en la tabla accounts para optimizar las consultas que buscan el balance de cuentas agrupadas por client_id?

