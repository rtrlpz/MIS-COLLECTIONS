import pandas as pd
import random
from faker import Faker
from datetime import datetime, timedelta
import numpy as np

# --- 1. Inicialización y Parámetros Globales ---
fake = Faker('es_ES')  # Usamos español para nombres realistas
random.seed(42)
np.random.seed(42)

# Parámetros Base
num_supervisors = 8
num_agents = 80
num_clients = 10000
start_date = datetime(2025, 10, 1)
end_date = datetime(2025, 10, 31)
date_range = pd.date_range(start=start_date, end=end_date)
# Horario de operación (minutos desde la medianoche)
MINUTO_INICIO_JORNADA = 8 * 60  # 8:00 AM
MINUTO_FIN_JORNADA = 22 * 60  # 10:00 PM


# --- 2. Funciones de Ayuda (Adaptadas) ---

def generate_call_duration():
    """Genera una duración de llamada en segundos (2 a 8 minutos)."""
    return random.randint(120, 480)


def generate_canal_y_contact():
    """Genera el canal y el tipo de contacto."""
    canal = random.choice(['Call', 'Inbound', 'Fico'])
    if canal == 'Call':
        tipo_contacto = random.choice(['Manual', 'Dialer'])
    elif canal == 'Inbound':
        tipo_contacto = 'Inbound'
    else:
        tipo_contacto = 'Fico'
    return canal, tipo_contacto


def generate_financials(product_type, days_past_due, balance_base):
    """
    Genera datos financieros realistas basados en el tipo de producto y días de mora.
    Adapta la lógica para usar un Balance Total predefinido (balance_base).
    """
    # 1. Definir límites y frecuencia base
    if product_type == 'Tarjeta':
        max_balance = 30000
        frecuencia_pago = 'Mensual'
    elif product_type == 'Prestamo':
        max_balance = 100000
        frecuencia_pago = random.choice(['Mensual', 'Bi-semanal', 'Semanal'])
    else:  # Hipoteca
        max_balance = 600000
        frecuencia_pago = random.choice(['Mensual', 'Bi-semanal'])

    balance_total = balance_base  # Usamos el balance de la cuenta

    # 2. Generar Pago Programado (Min Payment)
    pago_programado = 0.0
    if product_type == 'Tarjeta':
        # 2% del balance o 50 (lo que sea mayor), como pago mínimo
        pago_programado = round(max(50.0, 0.02 * balance_total), 2)
    elif product_type == 'Prestamo':
        # Simula un préstamo de 3-6 años
        pago_programado = round(balance_total / random.uniform(36, 72), 2)
    else:  # Hipoteca
        # Simula una hipoteca de 15-30 años
        pago_programado = round(balance_total / random.uniform(180, 360), 2)

    # 3. Generar Balance Adeudado (Past Due)
    balance_adeudado = 0.0
    status = 'Activo'  # Status inicial de la cuenta

    # Solo hay balance adeudado si hay días de mora
    if days_past_due > 0:
        status = 'Mora'
        # Calcular pagos omitidos
        if product_type == 'Tarjeta':  # Frecuencia de Tarjeta siempre mensual en la lógica original
            frecuencia_pago = 'Mensual'
            dias_base = 30
        elif frecuencia_pago == 'Mensual':
            dias_base = 30
        elif frecuencia_pago == 'Bi-semanal':
            dias_base = 14
        else:  # Semanal
            dias_base = 7

        num_pagos_omitidos = max(1, days_past_due // dias_base)

        # El balance adeudado es al menos los pagos omitidos
        # más un factor de interés/penalización para variabilidad
        base_due = num_pagos_omitidos * pago_programado

        # Lógica para aumento basado en días
        factor_atraso = (days_past_due / dias_base) * 0.1
        balance_adeudado = round(base_due * (1 + factor_atraso), 2)

        # Asegurar que el balance adeudado no supere el total
        balance_adeudado = min(balance_total, balance_adeudado)

    return {
        'BalanceTotal': balance_total,
        'BalanceAdeudado': balance_adeudado,
        'PagoProgramado': pago_programado,
        'FrecuenciaPago': frecuencia_pago,
        'StatusCuenta': status,
        'DiasMora': days_past_due
    }


# --- 3. Generación de Tablas Maestras ---

print("Generando Tablas Maestras...")

# 3.1 Supervisors
supervisors_data = []
team_names = [f"Team {i + 1}" for i in range(num_supervisors)]
regions = ['North', 'South', 'East', 'West']
for i in range(1, num_supervisors + 1):
    supervisors_data.append({
        'supervisor_id': i,
        'name': fake.name(),
        'team_name': team_names[(i - 1) % len(team_names)],
        'region': random.choice(regions)
    })
df_supervisors = pd.DataFrame(supervisors_data)

# 3.2 Agents
agents_data = []
for i in range(1, num_agents + 1):
    agents_data.append({
        'agent_id': i,
        'agent_name': fake.name(),
        'supervisor_id': random.randint(1, num_supervisors)
    })
df_agents = pd.DataFrame(agents_data)
# Mapeo de AgentID del script original al nuevo AgentID (necesario para el paso 5)
agent_id_map = {f"S{str(i).zfill(3)}": i for i in range(1, num_agents + 1)}

# 3.3 Products
products_data = []
product_types = ['Tarjeta', 'Prestamo', 'Hipoteca']
product_details = {
    'Tarjeta': {'name': 'Credit Card Standard', 'rate': 25.99, 'grace': 25, 'rule': '2% Balance or $50'},
    'Prestamo': {'name': 'Personal Loan 5yr', 'rate': 12.50, 'grace': 0, 'rule': 'Fixed Monthly Installment'},
    'Hipoteca': {'name': 'Mortgage 30yr', 'rate': 5.85, 'grace': 0, 'rule': 'Fixed Monthly Installment'}
}
product_counter = 1
for p_type in product_types:
    details = product_details[p_type]
    products_data.append({
        'product_id': product_counter,
        'product_name': details['name'],
        'product_type': p_type,
        'interest_rate': details['rate'],
        'grace_period_days': details['grace'],
        'default_min_payment_rule': details['rule']
    })
    product_counter += 1
df_products = pd.DataFrame(products_data)
product_map = {row['product_type']: row['product_id'] for _, row in df_products.iterrows()}

# 3.4 Clients
clients_data = []
segments = ['Retail', 'Premium', 'Tarjeta', 'Prestamo', 'Hipoteca']
for i in range(1, num_clients + 1):
    clients_data.append({
        'client_id': i,
        'name': fake.name(),
        'dob': fake.date_of_birth(minimum_age=25, maximum_age=65),
        'segment': random.choice(segments),
        'risk_score': round(random.uniform(500, 850), 2)
    })
df_clients = pd.DataFrame(clients_data)

# 3.5 Accounts
accounts_data = []
client_ids = df_clients['client_id'].tolist()
# Asumimos que cada cliente tiene 1-3 productos
account_counter = 1
for client_id in client_ids:
    num_products = random.randint(1, 3)
    # Seleccionamos productos únicos
    selected_product_types = random.sample(product_types, min(num_products, len(product_types)))

    for p_type in selected_product_types:
        product_id = product_map[p_type]
        open_date = fake.date_time_between(start_date='-5y', end_date='-6m').date()
        balance_base = round(random.uniform(100, 1) * product_details[p_type]['rate'] * 1000, 2)
        days_past_due = random.choices([0, random.randint(1, 180)], weights=[0.8, 0.2])[0]  # 20% en mora

        # Calcular datos financieros
        financials = generate_financials(p_type, days_past_due, balance_base)

        accounts_data.append({
            'account_id': account_counter,
            'client_id': client_id,
            'product_id': product_id,
            'open_date': open_date,
            'due_date': (start_date + timedelta(days=random.randint(1, 28))).date(),  # Fecha de pago aleatoria en Oct
            'min_payment': financials['PagoProgramado'],
            'balance': financials['BalanceTotal'],
            'status': financials['StatusCuenta'],
            'dias_mora': financials['DiasMora'],  # Columna temporal
            'balance_adeudado': financials['BalanceAdeudado'],  # Columna temporal
            'frecuencia_pago': financials['FrecuenciaPago']  # Columna temporal
        })
        account_counter += 1

df_accounts = pd.DataFrame(accounts_data)
# IDs de cuentas que están en mora (solo estas generarán promesas/curas)
mora_accounts = df_accounts[df_accounts['status'] == 'Mora']['account_id'].tolist()
all_accounts = df_accounts['account_id'].tolist()

print(f"Total de Cuentas: {len(df_accounts)}")
print(f"Cuentas en Mora: {len(mora_accounts)}")


# --- 4. Generación de Interacciones Diarias (Llamadas) ---

def generate_calls_for_agent_daily(current_agent_id, current_date, available_accounts):
    """
    Genera la lista de interacciones para un agente en un día específico.
    Utiliza IDs de cuenta y agente reales.
    """
    daily_interactions = []
    # Intenta contactar más a las cuentas en mora (70%) que a las al día (30%)
    accounts_to_contact = random.sample(mora_accounts, k=min(20, len(mora_accounts)))  # Hasta 20 cuentas en mora
    accounts_to_contact.extend(random.sample(all_accounts, k=random.randint(5, 15)))  # 5-15 cuentas al día
    accounts_to_contact = list(set(accounts_to_contact))  # Eliminar duplicados

    num_attempts = random.randint(80, 100)  # Número total de intentos

    for _ in range(num_attempts):
        # Seleccionar una cuenta al azar para el intento
        account_id = random.choice(accounts_to_contact)
        account_row = df_accounts[df_accounts['account_id'] == account_id].iloc[0]
        balance_total = account_row['balance']
        balance_adeudado = account_row['balance_adeudado']
        pago_programado = account_row['min_payment']
        dias_mora = account_row['dias_mora']
        estado_cuenta = account_row['status']

        # --- Datos de la Llamada ---
        canal, tipo_contacto = generate_canal_y_contact()
        duracion_segundos = generate_call_duration()
        duracion_minutos = duracion_segundos / 60
        duration_timedelta = timedelta(seconds=duracion_segundos)

        # --- Lógica de Interacción ---
        # 1. Conexión (calls_connected)
        is_connected = random.choices([True, False], weights=[0.8, 0.2])[0]
        # 2. RPC
        rpc_flag = False
        if is_connected:
            rpc_flag = random.choices([True, False], weights=[0.7, 0.3])[0]

        # 3. Promesa (PTP)
        promesa = 'No'
        cumplida = 'No'
        monto_promesa = 0.0
        fecha_promesa_pago = pd.NaT
        metodo_pago = ''

        if rpc_flag and estado_cuenta == 'Mora':
            promesa = random.choices(['Si', 'No'], weights=[0.7, 0.3])[0]

            if promesa == 'Si':
                min_monto = pago_programado * 0.5
                max_monto = balance_adeudado

                # Monto de la promesa
                if min_monto >= max_monto:
                    monto_promesa = round(max_monto, 2)
                else:
                    monto_promesa = round(random.uniform(min_monto, max_monto), 2)

                # Pago en el acto (Cure)
                cumplida = random.choices(['Si', 'No'], weights=[0.05, 0.95])[0]  # Menor probabilidad

                if cumplida == 'Si':
                    metodo_pago = random.choice(['OFI', 'Online', 'Branch/ATM'])
                    fecha_promesa_pago = current_date
                else:
                    # No pago en el acto: Asignar fecha futura (1-14 días)
                    dias_plazo = random.randint(1, 14)
                    fecha_promesa_pago = current_date + timedelta(days=dias_plazo)

        # Si no hubo RPC o no hubo promesa, el monto es 0
        if not rpc_flag or promesa == 'No':
            cumplida = 'No'
            monto_promesa = 0.0
            metodo_pago = ''

        # --- Tiempos de Llamada ---
        call_start_minute = random.randint(MINUTO_INICIO_JORNADA, MINUTO_FIN_JORNADA - int(duracion_minutos))
        hora_inicio = datetime.combine(current_date, datetime.min.time()) + timedelta(minutes=call_start_minute)
        hora_fin = hora_inicio + duration_timedelta

        aht_seconds = duracion_segundos
        acw_seconds = random.randint(10, 60)  # Trabajo post-llamada (10 a 60 seg)

        # --- Compilar Registro ---
        daily_interactions.append({
            'date': current_date.date(),
            'AgentID_Original': current_agent_id,
            'agent_id': df_agents[df_agents['agent_id'] == current_agent_id].iloc[0]['agent_id'],  # Nuevo Agent ID
            'account_id': account_id,
            'HoraInicioLlamada': hora_inicio,
            'HoraFinLlamada': hora_fin,
            'calls_attempted': 1,  # Un intento por registro de interacción
            'calls_connected': 1 if is_connected else 0,
            'rpc_flag': rpc_flag,
            'aht_seconds': aht_seconds,
            'acw_seconds': acw_seconds,
            'Promesa': promesa,  # Temporal para el PTP Log
            'MontoPromesa': monto_promesa,  # Temporal para el PTP Log
            'Cumplida': cumplida,  # Temporal para el Cures Log
            'FechaPromesaPago': fecha_promesa_pago,  # Temporal para el PTP Log
            'MetodoPago': metodo_pago,  # Temporal para el Cures Log
            'TipoContacto': tipo_contacto
        })

    return daily_interactions


# Generación Principal de Interacciones
print("\nGenerando Interacciones Diarias...")
all_interactions = []
for fecha_actual in date_range:
    print(f"... procesando {fecha_actual.date()}", end='\r')
    for agent_id in df_agents['agent_id'].tolist():
        calls = generate_calls_for_agent_daily(agent_id, fecha_actual, all_accounts)
        all_interactions.extend(calls)

df_interactions = pd.DataFrame(all_interactions)
print(f'\nTotal registros de interacción generados: {len(df_interactions)}')

# --- 5. Descomposición y Creación de Tablas de Hechos ---

# 5.1 Dialer Interactions (Agregación por Agente, Cuenta, Día y Tipo de Contacto 'Dialer')

# Filtramos solo el TipoContacto 'Dialer' y agrupamos para simular el registro diario
df_dialer_base = df_interactions[df_interactions['TipoContacto'] == 'Dialer'].copy()

# Calculamos el AHT y ACW promedio y sumamos los intentos y conexiones
df_dialer_interactions = df_dialer_base.groupby(['date', 'agent_id', 'account_id']).agg(
    calls_attempted=('calls_attempted', 'sum'),
    calls_connected=('calls_connected', 'sum'),
    rpc_flag=('rpc_flag', 'max'),  # Si hubo un RPC en el día, marcamos True
    aht_seconds=('aht_seconds', 'mean'),
    acw_seconds=('acw_seconds', 'mean')
).reset_index()

# Formateo final
df_dialer_interactions['rpc_flag'] = df_dialer_interactions['rpc_flag'].astype(bool)
df_dialer_interactions['aht_seconds'] = df_dialer_interactions['aht_seconds'].round(0).astype(int)
df_dialer_interactions['acw_seconds'] = df_dialer_interactions['acw_seconds'].round(0).astype(int)
df_dialer_interactions.insert(0, 'interaction_id', range(1, len(df_dialer_interactions) + 1))

# 5.2 PTP Log (Promesas)
# Filtramos solo las interacciones donde se hizo una promesa
df_ptp_log = df_interactions[df_interactions['Promesa'] == 'Si'].copy()

df_ptp_log['status'] = np.where(
    df_ptp_log['Cumplida'] == 'Si',
    'Kept',
    'Pending'  # Asumimos que inicialmente es Pending
)

df_ptp_log = df_ptp_log[['date', 'agent_id', 'account_id', 'MontoPromesa', 'status']].copy()
df_ptp_log.rename(columns={'date': 'date_of_interaction', 'MontoPromesa': 'amount_promised'}, inplace=True)
df_ptp_log.insert(0, 'ptp_id', range(1, len(df_ptp_log) + 1))

# 5.3 Cures Log (Pagos Instantáneos)
# Filtramos solo las promesas que se cumplieron en el acto (Cumplida = 'Si')
df_cures_log = df_interactions[df_interactions['Cumplida'] == 'Si'].copy()

# Un "Cure" es el monto prometido
df_cures_log['amount_paid'] = df_cures_log['MontoPromesa']
df_cures_log.rename(columns={'date': 'payment_date', 'MetodoPago': 'payment_method'}, inplace=True)

df_cures_log = df_cures_log[['payment_date', 'agent_id', 'account_id', 'amount_paid', 'payment_method']].copy()
df_cures_log.insert(0, 'cure_id', range(1, len(df_cures_log) + 1))

# 5.4 Agent Time Log (Horas Operativas y THT)
# Agrupamos las interacciones por agente y día
df_time_base = df_interactions.copy()
df_time_log = df_time_base.groupby(['date', 'agent_id']).agg(
    login_time=('HoraInicioLlamada', 'min'),
    logout_time=('HoraFinLlamada', 'max'),
    total_aht=('aht_seconds', 'sum'),
    total_acw=('acw_seconds', 'sum')
).reset_index()

# Cálculo de Métricas de Tiempo
df_time_log['login_time'] = df_time_log['login_time'].dt.time
df_time_log['logout_time'] = df_time_log['logout_time'].dt.time
df_time_log['tht_seconds'] = df_time_log['total_aht'] + df_time_log['total_acw']

# Simulación de Tiempos no registrados (Break y Operational Hours)
df_time_log['break_minutes'] = np.random.randint(45, 90, size=len(df_time_log))
df_time_log['scheduled_total_minutes'] = (MINUTO_FIN_JORNADA - MINUTO_INICIO_JORNADA)  # 14 horas = 840 minutos

# Tiempo total logged (minutos)
df_time_log['logged_seconds'] = (pd.to_datetime(df_time_log['logout_time'].astype(str)) - pd.to_datetime(
    df_time_log['login_time'].astype(str))).dt.total_seconds()

# Operational Hours = (Logged Time - Break) / 3600
df_time_log['operational_hours'] = ((df_time_log['logged_seconds'] - (df_time_log['break_minutes'] * 60)) / 3600).clip(
    lower=0).round(2)
df_time_log['tht_hours'] = (df_time_log['tht_seconds'] / 3600).round(2)
df_time_log['utilization'] = (
            df_time_log['tht_seconds'] / (df_time_log['logged_seconds'] - (df_time_log['break_minutes'] * 60))).clip(
    upper=1.0).round(2)

df_time_log.rename(columns={'date': 'date'}, inplace=True)

df_time_log = df_time_log[['date', 'agent_id', 'login_time', 'logout_time',
                           'break_minutes', 'operational_hours', 'tht_hours',
                           'scheduled_total_minutes', 'utilization']].copy()

df_time_log.insert(0, 'time_id', range(1, len(df_time_log) + 1))
df_time_log.rename(columns={'scheduled_total_minutes': 'schedule_time'}, inplace=True)
# Convertir schedule_time a DATETIME (aunque el nombre sugiere un int de minutos)
df_time_log['schedule_time'] = pd.to_datetime(df_time_log['date']) + pd.to_timedelta(df_time_log['schedule_time'],
                                                                                     unit='m')

# 5.5 Payment Schedule (Pagos Programados Mensuales de la Cuenta)
# Creamos una entrada por cada cuenta para simular su pago mensual
df_payment_schedule = df_accounts[['account_id', 'due_date', 'min_payment', 'status']].copy()
df_payment_schedule.rename(columns={'min_payment': 'expected_amount'}, inplace=True)

# Mapeo de estado de cuenta a estado de la programación de pago
status_map = {'Activo': 'Pending', 'Mora': 'Overdue', 'Cerrado': 'Paid'}
df_payment_schedule['status'] = df_payment_schedule['status'].map(status_map)

# Para las cuentas 'Activo' (Pending), 10% ya pagaron en Oct
paid_indices = df_payment_schedule[df_payment_schedule['status'] == 'Pending'].sample(frac=0.1, random_state=42).index
df_payment_schedule.loc[paid_indices, 'status'] = 'Paid'

df_payment_schedule.insert(0, 'schedule_id', range(1, len(df_payment_schedule) + 1))

# --- 6. Limpieza y Presentación ---

# Cuentas: Eliminamos columnas temporales
df_accounts.drop(columns=['dias_mora', 'balance_adeudado', 'frecuencia_pago'], inplace=True)

print("\n--- Vista Previa de DataFrames Generados ---")
print("Clients:", len(df_clients))
print("Accounts:", len(df_accounts))
print("Supervisors:", len(df_supervisors))
print("Agents:", len(df_agents))
print("Products:", len(df_products))
print("Dialer Interactions (Hecho):", len(df_dialer_interactions))
print("PTP Log (Hecho):", len(df_ptp_log))
print("Cures Log (Hecho):", len(df_cures_log))
print("Agent Time Log (Hecho):", len(df_time_log))
print("Payment Schedule (Soporte):", len(df_payment_schedule))

print("\n--- Primeros 5 Registros de Dialer Interactions ---")
print(df_dialer_interactions.head())

# --- 7. Guardar en CSV (Simulando Exportación a la DB) ---

# Lista de DataFrames para guardar
dataframes_to_save = {
    'clients': df_clients,
    'products': df_products,
    'accounts': df_accounts,
    'supervisors': df_supervisors,
    'agents': df_agents,
    'dialer_interactions': df_dialer_interactions,
    'ptp_log': df_ptp_log,
    'cures_log': df_cures_log,
    'agent_time_log': df_time_log,
    'payment_schedule': df_payment_schedule
}

output_dir = '../01_Data_Sources/sql_schema_data'
# Crear directorio si no existe (esto no se puede hacer directamente en el código de respuesta)
import os
os.makedirs(output_dir, exist_ok=True)

# Simulación de guardado
for name, df in dataframes_to_save.items():
     path = f"{output_dir}/{name}.csv"
     df.to_csv(path, index=False)
     print(f"Datos de {name} guardados en: {path}")

# Ejemplo de los DataFrames finales:
# print("\nFinal DataFrame structure for 'dialer_interactions':")
# print(df_dialer_interactions.dtypes)