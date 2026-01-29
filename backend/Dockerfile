FROM python:3.11-slim

WORKDIR /app

# Instalar dependencias del sistema
RUN apt-get update && apt-get install -y \
    gcc \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Copiar requirements primero para cache
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copiar el resto de la aplicación
COPY . .

# Puerto expuesto
EXPOSE 8000

# Comando para ejecutar
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]