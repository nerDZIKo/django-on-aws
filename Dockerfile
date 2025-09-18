# Dockerfile (jeśli nie masz)
FROM python:3.11-slim

WORKDIR /app

# Instalacja zależności systemowych
RUN apt-get update && apt-get install -y \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Kopiowanie i instalacja zależności Python
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Kopiowanie kodu aplikacji
COPY app/ .

# Tworzenie użytkownika non-root
RUN adduser --disabled-password --gecos '' appuser && chown -R appuser /app
USER appuser

# Health check endpoint (dodaj do Django jeśli nie masz)
EXPOSE 8080

# Komenda startowa
CMD ["python", "manage.py", "runserver", "0.0.0.0:8080"]