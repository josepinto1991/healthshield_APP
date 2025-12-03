#!/usr/bin/env python3
"""
Script para inicializar la base de datos manualmente
Uso: python scripts/init_db.py
"""
import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from database import init_db, engine
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

if __name__ == "__main__":
    try:
        logger.info("🔄 Inicializando base de datos...")
        init_db()
        logger.info("✅ Base de datos inicializada exitosamente")
    except Exception as e:
        logger.error(f"❌ Error: {e}")
        sys.exit(1)