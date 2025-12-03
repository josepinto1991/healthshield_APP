# Dockerfile optimizado para Render
FROM python:3.11-slim

WORKDIR /app

# Instalar solo lo necesario
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Copiar requirements primero (caché de Docker)
COPY requirements.txt .

# Instalar dependencias
RUN pip install --no-cache-dir -r requirements.txt

# Copiar aplicación
COPY . .

# Crear usuario no-root para seguridad
RUN useradd -m -u 1000 renderuser && chown -R renderuser:renderuser /app
USER renderuser

# Puerto que usa Render
EXPOSE 10000

# Comando de inicio
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "10000", "--log-level", "info"]