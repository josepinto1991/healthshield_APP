// lib/screens/sync_screen.dart - VERSIÓN CORREGIDA PARA connectivity_plus 4.0+
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/bidirectional_sync_service.dart';
import '../services/api_service.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({Key? key}) : super(key: key);

  @override
  _SyncScreenState createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  bool _isSyncing = false;
  Map<String, dynamic> _syncStatus = {};
  String? _lastError;
  bool _hasNetwork = true;
  bool _hasInternet = true;
  bool _checkingConnection = false;
  ConnectivityResult _currentConnectivity = ConnectivityResult.none;

  @override
  void initState() {
    super.initState();
    _checkNetworkConnection();
    _loadSyncStatus();
    
    // Escuchar cambios de conectividad en tiempo real - VERSIÓN CORREGIDA
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.isNotEmpty) {
        _updateNetworkStatus(results.first);
      }
    });
  }

  Future<void> _checkNetworkConnection() async {
    try {
      final List<ConnectivityResult> results = await Connectivity().checkConnectivity();
      if (results.isNotEmpty) {
        _updateNetworkStatus(results.first);
      } else {
        setState(() {
          _hasNetwork = false;
          _hasInternet = false;
          _currentConnectivity = ConnectivityResult.none;
        });
      }
    } catch (e) {
      print('Error verificando conectividad: $e');
      setState(() {
        _hasNetwork = false;
        _hasInternet = false;
        _currentConnectivity = ConnectivityResult.none;
      });
    }
  }

  void _updateNetworkStatus(ConnectivityResult result) {
    setState(() {
      _currentConnectivity = result;
      _hasNetwork = result != ConnectivityResult.none;
      
      // Si no hay red, definitivamente no hay internet
      if (!_hasNetwork) {
        _hasInternet = false;
      }
    });
    
    // Si hay red, verificar conexión real a internet
    if (_hasNetwork) {
      _checkRealInternetConnection();
    }
  }

  Future<void> _checkRealInternetConnection() async {
    setState(() {
      _checkingConnection = true;
    });

    try {
      final hasRealConnection = await _performInternetTest();
      
      setState(() {
        _hasInternet = hasRealConnection;
        _checkingConnection = false;
      });
      
    } catch (e) {
      setState(() {
        _hasInternet = false;
        _checkingConnection = false;
      });
    }
  }

  Future<bool> _performInternetTest() async {
    try {
      // Método 1: Intentar conectar al servidor
      final syncService = Provider.of<BidirectionalSyncService>(context, listen: false);
      final hasServerConnection = await syncService.hasInternetConnection();
      
      if (hasServerConnection) return true;
      
      // Método 2: Intentar ping simple basado en tipo de conexión
      return await _simplePingTest();
      
    } catch (e) {
      return false;
    }
  }

  Future<bool> _simplePingTest() async {
    try {
      // Basado en el tipo de conexión actual
      switch (_currentConnectivity) {
        case ConnectivityResult.wifi:
        case ConnectivityResult.mobile:
        case ConnectivityResult.ethernet:
        case ConnectivityResult.vpn:
        case ConnectivityResult.bluetooth:
          return true;
        case ConnectivityResult.none:
        default:
          return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<void> _loadSyncStatus() async {
    try {
      final syncService = Provider.of<BidirectionalSyncService>(context, listen: false);
      final status = await syncService.getSyncStatus();
      setState(() {
        _syncStatus = status;
        _lastError = null;
      });
    } catch (e) {
      print('Error cargando estado de sincronización: $e');
      setState(() {
        _lastError = 'No se pudo cargar el estado de sincronización';
      });
    }
  }

  Future<void> _performSync() async {
    // Verificar conexión REAL a internet
    await _checkRealInternetConnection();
    
    if (!_hasInternet) {
      setState(() {
        _lastError = 'No hay conexión a internet. Verifica tu conexión e intenta de nuevo.';
      });
      return;
    }

    setState(() {
      _isSyncing = true;
      _lastError = null;
    });

    try {
      final syncService = Provider.of<BidirectionalSyncService>(context, listen: false);
      
      // Verificar nuevamente antes de sincronizar
      final hasConnection = await syncService.hasInternetConnection();
      
      if (!hasConnection) {
        setState(() {
          _isSyncing = false;
          _lastError = 'El servidor no está disponible en este momento. Los datos se guardarán localmente.';
        });
        return;
      }
      
      await syncService.manualSync();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sincronización completada exitosamente.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      
      await _loadSyncStatus();
      
    } catch (e) {
      print('Error en sincronización: $e');
      
      String errorMessage;
      if (e.toString().contains('Failed host lookup') || 
          e.toString().contains('Connection refused')) {
        errorMessage = 'No se puede conectar al servidor. Verifica la URL del servidor.';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'Tiempo de espera agotado. El servidor puede estar muy lento o caído.';
      } else {
        errorMessage = 'Error en la sincronización. Verifica tu conexión.';
      }
      
      setState(() {
        _lastError = errorMessage;
        _hasInternet = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  Widget _buildStatusItem(String title, String value, IconData icon, Color color) {
    return ListTile(
      leading: Icon(icon, color: color, size: 20),
      title: Text(
        title, 
        style: const TextStyle(fontSize: 14),
      ),
      trailing: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  Widget _buildInfoCard(String title, String subtitle, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: color, size: 20),
        title: Text(
          title, 
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          subtitle, 
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  String _getConnectionTypeText() {
    switch (_currentConnectivity) {
      case ConnectivityResult.wifi:
        return 'WiFi';
      case ConnectivityResult.mobile:
        return 'Datos móviles';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.vpn:
        return 'VPN';
      case ConnectivityResult.bluetooth:
        return 'Bluetooth';
      case ConnectivityResult.none:
      default:
        return 'Ninguna';
    }
  }

  Widget _buildConnectionStatus() {
    IconData icon;
    Color color;
    String text;
    String subtitle = '';
    
    if (_checkingConnection) {
      icon = Icons.wifi;
      color = Colors.orange;
      text = 'Verificando conexión...';
    } else if (!_hasNetwork) {
      icon = Icons.wifi_off;
      color = Colors.red;
      text = 'Sin conexión de red';
      subtitle = 'Conecta a WiFi o activa datos móviles';
    } else if (!_hasInternet) {
      icon = Icons.wifi_off;
      color = Colors.orange;
      text = 'Sin acceso a internet';
      subtitle = 'Red: ${_getConnectionTypeText()} - Sin internet';
    } else {
      icon = Icons.wifi;
      color = Colors.green;
      text = 'Conectado a internet';
      subtitle = 'Red: ${_getConnectionTypeText()}';
    }
    
    return Card(
      color: color.withOpacity(0.1),
      child: ListTile(
        leading: _checkingConnection
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, color: color),
        title: Text(
          text, 
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
        subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_hasNetwork && !_hasInternet && !_checkingConnection)
              IconButton(
                icon: const Icon(Icons.info, size: 18),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Problema de conexión'),
                      content: const Text(
                        'Hay conexión de red pero no se puede acceder a internet. '
                        'Posibles causas:\n\n'
                        '• VPN o proxy activado\n'
                        '• Firewall bloqueando conexiones\n'
                        '• Problema con el proveedor de internet\n'
                        '• Servidor no disponible',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Entendido'),
                        ),
                      ],
                    ),
                  );
                },
                tooltip: 'Más información',
              ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              onPressed: _checkingConnection ? null : _checkRealInternetConnection,
              tooltip: 'Verificar conexión',
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      
      appBar: AppBar(
        title: const Text(
          'Sincronización',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _loadSyncStatus,
            tooltip: 'Actualizar estado',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, size: 20),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Información de Sincronización'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Estado de red:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(_hasNetwork ? '✅ Conectado a red' : '❌ Sin red'),
                        
                        const SizedBox(height: 8),
                        const Text('Tipo de conexión:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(_getConnectionTypeText()),
                        
                        const SizedBox(height: 8),
                        const Text('Estado de internet:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(_hasInternet ? '✅ Conectado a internet' : '❌ Sin internet'),
                        
                        const SizedBox(height: 12),
                        const Text('Registros pendientes:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('Vacunas: ${_syncStatus['vacunas_pendientes'] ?? '0'}'),
                        Text('Usuarios: ${_syncStatus['usuarios_pendientes'] ?? '0'}'),
                        Text('Operaciones: ${_syncStatus['operaciones_pendientes'] ?? '0'}'),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cerrar'),
                    ),
                  ],
                ),
              );
            },
            tooltip: 'Información',
          ),
        ],
      ),
      
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Estado de conexión
              _buildConnectionStatus(),
              
              const SizedBox(height: 16),
              
              // Mostrar error si existe
              if (_lastError != null)
                Card(
                  color: Colors.red[50],
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _lastError!,
                            style: const TextStyle(color: Colors.red, fontSize: 13),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            setState(() {
                              _lastError = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              
              if (_lastError != null) const SizedBox(height: 16),
              
              // Estadísticas de sincronización
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildStatusItem(
                        'Usuarios pendientes',
                        _syncStatus['usuarios_pendientes']?.toString() ?? '0',
                        Icons.people,
                        Colors.blue,
                      ),
                      _buildStatusItem(
                        'Vacunas pendientes',
                        _syncStatus['vacunas_pendientes']?.toString() ?? '0',
                        Icons.medical_services,
                        Colors.green,
                      ),
                      _buildStatusItem(
                        'Operaciones pendientes',
                        _syncStatus['operaciones_pendientes']?.toString() ?? '0',
                        Icons.sync,
                        Colors.orange,
                      ),
                      const Divider(),
                      _buildStatusItem(
                        'Última sincronización',
                        _syncStatus['ultima_sincronizacion'] != null 
                            ? _formatDate(_syncStatus['ultima_sincronizacion'])
                            : 'Nunca',
                        Icons.access_time,
                        Colors.purple,
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Botón de sincronización
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: (_isSyncing || !_hasInternet || _checkingConnection) 
                      ? null 
                      : _performSync,
                  icon: _isSyncing 
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white, 
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.sync, size: 20),
                  label: Text(
                    _isSyncing ? 'Sincronizando...' : 'Sincronizar Ahora',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _hasInternet ? Colors.blue : Colors.grey,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              Expanded(
                child: ListView(
                  children: [
                    _buildInfoCard(
                      'Sincronización Automática',
                      'Los datos se sincronizan automáticamente cuando hay conexión',
                      Icons.wifi,
                      Colors.blue,
                    ),
                    _buildInfoCard(
                      'Modo Offline',
                      'Puedes trabajar sin conexión y los datos se sincronizarán después',
                      Icons.offline_bolt,
                      Colors.orange,
                    ),
                    _buildInfoCard(
                      'Datos Seguros',
                      'La información se guarda localmente mientras no haya conexión',
                      Icons.security,
                      Colors.green,
                    ),
                    _buildInfoCard(
                      'Nota Importante',
                      'Se requiere conexión REAL a internet (no solo red WiFi)',
                      Icons.info,
                      Colors.purple,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }
}