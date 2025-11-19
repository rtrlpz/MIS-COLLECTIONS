import pandas as pd
import matplotlib.pyplot as plt

df = pd.read_csv('../01_Data_Sources/sql_schema_data/dialer_interactions.csv')
print(df.head())

avg_aht_rpc = df[df['rpc_flag'] == True]['aht_seconds'].mean().round(2)
print("\nAverage AHT for RPCs:", avg_aht_rpc)

print(f"\n{df.info()}")


# Relacion de Calls Connected / Calls attemted
df['connection_ratio'] = df['calls_connected'] / df['calls_attempted']
agent_ratios = df.groupby('agent_id')['connection_ratio'].mean().reset_index()
print(agent_ratios)


# Total RPCs por agent
rpc_counts = df[df['rpc_flag'] == True].groupby('agent_id').size().reset_index(name='total_rpcs')

# Grafico de barras
plt.figure(figsize=(10, 6))
plt.bar(rpc_counts['agent_id'], rpc_counts['total_rpcs'], color='blue')
plt.xlabel('agent')
plt.ylabel('Total RPCs')
plt.title('Total RPCs by Agent')
plt.xticks(rotation=45)
plt.tight_layout()
plt.show()