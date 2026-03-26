from io import StringIO
import os
import pandas as pd
import psycopg2
from pathlib import Path
from dotenv import load_dotenv

"""
Antes de correr este script, asegurarse que la base de datos y sus tablas han sido creadas. 
"""

# Agrega esta línea para que Python lea el archivo .env
load_dotenv()

# Obtenemos las variables. Si no existen en el .env, retornarán None.
DB_USER = os.getenv('POSTGRES_USER')
DB_PASSWORD = os.getenv('POSTGRES_PASSWORD')
DB_NAME = os.getenv('POSTGRES_DB')
DB_PORT = os.getenv('POSTGRES_PORT', '5433') # El puerto no es sensible, puede tener default
DB_HOST = os.getenv('POSTGRES_HOST', 'localhost')

# Validación de seguridad: Si falta alguna clave, detenemos el script de inmediato.
if not all([DB_USER, DB_PASSWORD, DB_NAME]):
    raise ValueError("🔒 ERROR: Faltan credenciales. Asegúrate de que el archivo .env existe y contiene POSTGRES_USER, POSTGRES_PASSWORD y POSTGRES_DB.")


# --- 1. CONFIGURACION DE CONEXION A DB Y DATOS ---#
DB_CONFIG = {
    'host': DB_HOST,
    'database': DB_NAME,
    'user': DB_USER,
    'password': DB_PASSWORD,
    'port': DB_PORT
}

# Ruta RELATIVA: Sube un nivel desde 02_database/ y entra a 01_data_sources/
# Esto asegura que funcione en cualquier computadora donde se clone el repositorio
BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / '01_data_sources' / 'raw_csv'


# Orden de ingesta para respetar las dependencias de claves foraneas
TABLE_ORDER = [
    'supervisors',
    'agents',
    'clients',
    'products',
    'accounts',
    'payment_schedule',
    'dialer_interactions',
    'agent_time_log',
    'ptp_log',
    'cures_log'
]


# --- 2. FUNCIÓN PARA LA INGESTA ---
def ingest_data_to_pg(df: pd.DataFrame, table_name: str, conn):
    """ Cargar un DataFrame de pandas a una tabla de PostgreSQL usando COPY_FROM """
    print(f"Ingesting {table_name}...")

    # Prepara los datos para COPY FROM: convierte dataframe a un objeto StringIO
    buffer = StringIO()

    # Coincidir los encabezados de las columnas con los nombres de las columnas en la tabla SQL
    df.to_csv(buffer, header=True, index=False)
    buffer.seek(0)
    buffer.readline()

    cursor = conn.cursor()

    try:
        cursor.copy_from(
            file=buffer,
            table=table_name,
            sep=',',
            columns=df.columns.tolist()
        )
        conn.commit()
        print(f"Ingested {table_name} to PostgreSQL completed. {len(df)} records inserted.")

    except (Exception, psycopg2.Error) as error:
        print(f"Error while ingesting {table_name}: {error}")
        conn.rollback()
    finally:
        cursor.close()


# --- 3. PROCESO PRINCIPAL ---
def main():
    """ Conecta a la base de datos """
    conn = None
    try:
        print('Trying to connect to PostgreSQL...')
        conn = psycopg2.connect(**DB_CONFIG)
        print('Connected to PostgreSQL')

        print('\n--- INGESTING DATA ---')

        for table_name in TABLE_ORDER:
            csv_file = DATA_DIR / f'{table_name}.csv'

            if not csv_file.exists():
                print(f"File {csv_file} not found.")
                continue

            df = pd.read_csv(csv_file)

            if 'rpc_flag' in df.columns:
                df['rpc_flag'] = df['rpc_flag'].astype(str).str.lower()

            ingest_data_to_pg(df, table_name, conn)

        print('\n--- INGESTING COMPLETE ---')

    except psycopg2.OperationalError as e:
        # This block requires psycopg2 to be successfully loaded
        print(f"\nFATAL: No se pudo conectar a la base de datos. Error: {e}")
    except Exception as e:
        print(f"Ocurrió un error inesperado: {e}")
    finally:
        if conn:
            conn.close()
            print("Connection closed.")

if __name__== '__main__':
    main()

