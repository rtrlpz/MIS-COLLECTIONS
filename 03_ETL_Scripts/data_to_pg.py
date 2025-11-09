from io import StringIO
import pandas as pd
import psycopg2
from pathlib import Path

"""
Antes de correr este script, asegurarse que la base de datos y sus tablas han sido creadas. 

"""
# --- 1. CONFIGURACION DE CONEXION A DB Y DATOS ---#
DB_CONFIG = {
    'host': 'localhost',
    'database': 'MSI_CollectionsDB',
    'user': 'airflow',
    'password': 'airflow',
    'port': 5432
}

# Ruta absoluta de la carpeta de datos
DATA_DIR = Path(r'C:\Users\Leand\Desktop\MIS-COLLECTIONS\01_Data_Sources\sql_schema_data')

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

