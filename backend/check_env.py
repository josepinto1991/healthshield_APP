# check_env.py
import os
print("=== VARIABLES DE ENTORNO EN RENDER ===")
for key, value in os.environ.items():
    print(f"{key}: {value[:50]}{'...' if len(value) > 50 else ''}")
print("======================================")