import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/bidirectional_sync_service.dart';

class SyncScreen extends StatefulWidget {
  @override
  _SyncScreenState createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  bool _isSyncing = false;
  Map<String, dynamic> _syncStatus = {};
  String? _lastError;
  bool _hasInternet = true;

  @override
  void initState() {
    super.initState();
    _checkInternetConnection();
    _loadSyncStatus();
  }

  Future<void> _checkInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      setState(() {
        _hasInternet = connectivityResult != ConnectivityResult.none;
      });
    } catch (e) {
      print('Error verificando conectividad: $e');
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
    // Verificar conexión a internet primero
    await _checkInternetConnection();
    
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
      
      // Verificar si el servidor está disponible
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
        SnackBar(
          content: Text('Sincronización completada exitosamente.'),
          backgroundColor: Colors.green,
        ),
      );
      
      await _loadSyncStatus();
      
    } catch (e) {
      print('Error en sincronización: $e');
      
      // ✅ MOSTRAR MENSAJE AMIGABLE EN LUGAR DEL ERROR TÉCNICO
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
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
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
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(fontSize: 14)),
      trailing: Text(
        value,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  Widget _buildInfoCard(String title, String subtitle, IconData icon, Color color) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    IconData icon;
    Color color;
    String text;
    
    if (!_hasInternet) {
      icon = Icons.wifi_off;
      color = Colors.red;
      text = 'Sin conexión a internet';
    } else {
      icon = Icons.wifi;
      color = Colors.green;
      text = 'Conectado a internet';
    }
    
    return Card(
      color: color.withOpacity(0.1),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        trailing: IconButton(
          icon: Icon(Icons.refresh, size: 18),
          onPressed: _checkInternetConnection,
          tooltip: 'Verificar conexión',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Sincronización',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, size: 20),
            onPressed: _loadSyncStatus,
            tooltip: 'Actualizar estado',
          ),
          IconButton(
            icon: Icon(Icons.info_outline, size: 20),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Información de Sincronización'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Estado de conexión:'),
                      Text(_hasInternet ? '✅ Conectado' : '❌ Sin conexión'),
                      SizedBox(height: 12),
                      Text('Registros pendientes:'),
                      Text('Vacunas: ${_syncStatus['vacunas_pendientes'] ?? '0'}'),
                      Text('Usuarios: ${_syncStatus['usuarios_pendientes'] ?? '0'}'),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cerrar'),
                    ),
                  ],
                ),
              );
            },
            tooltip: 'Información',
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Estado de conexión
            _buildConnectionStatus(),
            
            SizedBox(height: 16),
            
            // ✅ MOSTRAR ERROR SI EXISTE
            if (_lastError != null)
              Card(
                color: Colors.red[50],
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _lastError!,
                          style: TextStyle(color: Colors.red[700], fontSize: 13),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, size: 18),
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
            
            if (_lastError != null) SizedBox(height: 16),
            
            // Estadísticas de sincronización
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
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
                    Divider(),
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
            
            SizedBox(height: 24),
            
            // Botón de sincronización
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: (_isSyncing || !_hasInternet) ? null : _performSync,
                icon: _isSyncing 
                    ? CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    : Icon(Icons.sync, size: 20),
                label: Text(
                  _isSyncing ? 'Sincronizando...' : 'Sincronizar Ahora',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _hasInternet ? Colors.blue : Colors.grey,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
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
                    'Nota',
                    'La sincronización requiere conexión a internet',
                    Icons.info,
                    Colors.purple,
                  ),
                ],
              ),
            ),
          ],
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