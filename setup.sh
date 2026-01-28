#!/bin/bash
echo "=== DEBUG START ==="
echo "Directorio actual: $(pwd)"
echo "=== Estructura: ==="
ls -la
echo "=== Buscando backend: ==="
find . -type d -name "*backend*"
echo "=== Buscando requirements.txt: ==="
find . -name "requirements.txt"
echo "=== DEBUG END ==="