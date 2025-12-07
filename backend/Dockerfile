# FROM python:3.11-slim

# WORKDIR /app

# # Instalar dependencias del sistema
# RUN apt-get update && apt-get install -y \
#     gcc \
#     libpq-dev \
#     && rm -rf /var/lib/apt/lists/*

# # Copiar requirements
# COPY requirements.txt .

# # Instalar dependencias Python
# RUN pip install --no-cache-dir -r requirements.txt

# # Copiar código
# COPY . .

# # Variables de entorno por defecto
# ENV ENVIRONMENT=production
# ENV PORT=8000

# # Exponer puerto
# EXPOSE 8000

# # Comando de inicio
# CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]

FROM python:3.11-slim

WORKDIR /app

# Instalar dependencias del sistema
RUN apt-get update && apt-get install -y \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Copiar requirements
COPY requirements.txt .

# Instalar dependencias Python
RUN pip install --no-cache-dir -r requirements.txt

# Copiar código
COPY . .

# Variables de entorno por defecto
ENV PYTHONUNBUFFERED=1
ENV PORT=8000

# Exponer puerto (Render usa 10000 internamente)
EXPOSE 8000

# Comando de inicio
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]