#!/bin/bash
echo "=== RAILWAY DEBUG ==="
echo "Python version:"
python3 --version || echo "No python3"
echo "Pip version:"
pip3 --version || pip --version || echo "No pip"
echo "=== Structure ==="
find . -type d | sort
echo "=== Backend search ==="
find . -name "requirements.txt"
echo "=== END DEBUG ==="