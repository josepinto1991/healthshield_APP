# validar_profesional.py
import requests
import re
import json
import html
import urllib3
import time
from typing import Dict, Any, Optional, List
from datetime import datetime

# Desactivar warnings de SSL
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

class ProfesionalValidator:
    """
    Validador de profesionales de la salud para SACS (Venezuela)
    Consulta el sistema: https://sistemas.sacs.gob.ve/consultas/prfsnal_salud
    """
    
    BASE_URL = "https://sistemas.sacs.gob.ve/consultas/prfsnal_salud"
    
    @staticmethod
    def _clean_text(text: str) -> str:
        """Limpiar texto de caracteres especiales"""
        if not text:
            return ""
        # Decodificar entidades HTML
        cleaned = html.unescape(text)
        # Remover espacios extra
        cleaned = ' '.join(cleaned.split())
        return cleaned.strip()
    
    @staticmethod
    def _extract_user_data(response_text: str) -> Optional[Dict[str, Any]]:
        """Extraer datos personales del profesional"""
        # Buscar xajax_userTable
        user_match = re.search(r"xajax_userTable\('(.+?)'\)", response_text)
        if not user_match:
            return None
        
        try:
            user_json = user_match.group(1)
            user_data = json.loads(user_json)
            
            return {
                "nombre": ProfesionalValidator._clean_text(f"{user_data.get('nombre1', '')} {user_data.get('apellido1', '')}"),
                "cedula": user_data.get('cedula', ''),
                "tipo_cedula": user_data.get('tipo_cedula', ''),
                "estatus": user_data.get('estatus', ''),
            }
        except (json.JSONDecodeError, KeyError) as e:
            return None
    
    @staticmethod
    def _extract_professional_data(response_text: str) -> List[Dict[str, Any]]:
        """Extraer datos profesionales/registros"""
        prof_match = re.search(r"xajax_tableProfesion\('(.+?)'\)", response_text)
        if not prof_match:
            return []
        
        try:
            prof_json = prof_match.group(1)
            prof_data = json.loads(prof_json)
            
            registros = []
            if isinstance(prof_data, list):
                for prof in prof_data:
                    registro = {
                        "profesion": ProfesionalValidator._clean_text(prof.get('profesion', '')),
                        "licencia": prof.get('licencia', ''),
                        "fecha_registro": prof.get('fecha_registro', ''),
                        "tomo_registro": prof.get('tomo_registro', ''),
                        "folio_registro": prof.get('folio_registro', ''),
                        "numero_registro": prof.get('numero_registro', ''),
                    }
                    registros.append(registro)
            
            return registros
        except (json.JSONDecodeError, KeyError) as e:
            return []
    
    @staticmethod
    def validate_cedula(cedula: str) -> Dict[str, Any]:
        """
        Validar una cédula profesional en el sistema SACS
        
        Args:
            cedula: Número de cédula a validar (ej: 'V-12345678' o 'E-12345678')
            
        Returns:
            Dict con los datos del profesional
        """
        if not cedula:
            return {
                "success": False,
                "error": "La cédula no puede estar vacía",
                "cedula": cedula,
                "timestamp": datetime.now().isoformat()
            }
        
        # Validar formato básico
        if not re.match(r'^[VE]-\d{7,8}$', cedula.upper()):
            return {
                "success": False,
                "error": "Formato de cédula inválido. Use: V-12345678 o E-12345678",
                "cedula": cedula,
                "timestamp": datetime.now().isoformat()
            }
        
        # Preparar payload para la solicitud POST
        payload = {
            'xajax': 'getPrfsnalByCed',
            'xajaxr': int(time.time() * 1000),  # Timestamp en milisegundos
            'xajaxargs[]': cedula
        }
        
        # Headers para simular navegador
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Accept': '*/*',
            'Accept-Language': 'es-ES,es;q=0.9',
            'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
            'Origin': 'https://sistemas.sacs.gob.ve',
            'Referer': 'https://sistemas.sacs.gob.ve/consultas/prfsnal_salud',
        }
        
        try:
            print(f"🔍 Validando cédula: {cedula}")
            
            # Realizar solicitud POST
            response = requests.post(
                ProfesionalValidator.BASE_URL,
                data=payload,
                headers=headers,
                verify=False,
                timeout=30
            )
            
            if response.status_code != 200:
                return {
                    "success": False,
                    "error": f"Error en la consulta: HTTP {response.status_code}",
                    "cedula": cedula,
                    "timestamp": datetime.now().isoformat()
                }
            
            # Extraer datos de la respuesta
            response_text = response.text
            
            user_data = ProfesionalValidator._extract_user_data(response_text)
            professional_data = ProfesionalValidator._extract_professional_data(response_text)
            
            if not user_data and not professional_data:
                # Verificar si hay mensaje de error
                if "NO SE ENCONTRÓ REGISTRO" in response_text.upper():
                    return {
                        "success": False,
                        "is_valid": False,
                        "error": "Profesional no encontrado en el registro",
                        "cedula": cedula,
                        "timestamp": datetime.now().isoformat()
                    }
                elif "Cédula" in response_text and "inválida" in response_text.lower():
                    return {
                        "success": False,
                        "is_valid": False,
                        "error": "Cédula inválida",
                        "cedula": cedula,
                        "timestamp": datetime.now().isoformat()
                    }
                else:
                    return {
                        "success": False,
                        "is_valid": False,
                        "error": "No se pudieron extraer datos de la respuesta",
                        "cedula": cedula,
                        "timestamp": datetime.now().isoformat()
                    }
            
            # Determinar si es válido
            is_valid = bool(user_data and professional_data)
            
            result = {
                "success": True,
                "cedula": cedula,
                "is_valid": is_valid,
                "timestamp": datetime.now().isoformat(),
                "user_data": user_data,
                "professional_data": professional_data,
            }
            
            if is_valid:
                print(f"✅ Profesional encontrado: {user_data.get('nombre', 'N/A')}")
            else:
                print(f"❌ Profesional no encontrado o datos incompletos")
            
            return result
            
        except requests.exceptions.Timeout:
            return {
                "success": False,
                "is_valid": False,
                "error": "Timeout al consultar el sistema SACS",
                "cedula": cedula,
                "timestamp": datetime.now().isoformat()
            }
        except requests.exceptions.ConnectionError:
            return {
                "success": False,
                "is_valid": False,
                "error": "Error de conexión con el sistema SACS",
                "cedula": cedula,
                "timestamp": datetime.now().isoformat()
            }
        except Exception as e:
            return {
                "success": False,
                "is_valid": False,
                "error": f"Error inesperado: {str(e)[:100]}",
                "cedula": cedula,
                "timestamp": datetime.now().isoformat()
            }