import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/bidirectional_sync_service.dart';

class SyncScreen extends StatefulWidget {
  @override
  _SyncScreenState createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  bool _isSyncing = false;
  Map<String, dynamic> _syncStatus = {};

  @override
  void initState() {
    super.initState();
    _loadSyncStatus();
  }

  Future<void> _loadSyncStatus() async {
    final syncService = Provider.of<BidirectionalSyncService>(context, listen: false);
    final status = await syncService.getSyncStatus();
    setState(() {
      _syncStatus = status;
    });
  }

  Future<void> _performSync() async {
    setState(() {
      _isSyncing = true;
    });

    try {
      final syncService = Provider.of<BidirectionalSyncService>(context, listen: false);
      await syncService.manualSync();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Sincronización completada exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
      
      await _loadSyncStatus();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error en sincronización: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'HealthShield',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadSyncStatus,
            tooltip: 'Actualizar estado',
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sincronización de Datos',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            
            SizedBox(height: 16),
            
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildStatusItem(
                      'Usuarios pendientes',
                      _syncStatus['usuarios_pendientes']?.toString() ?? '0',
                      Icons.people,
                    ),
                    _buildStatusItem(
                      'Vacunas pendientes',
                      _syncStatus['vacunas_pendientes']?.toString() ?? '0',
                      Icons.medical_services,
                    ),
                    _buildStatusItem(
                      'Operaciones pendientes',
                      _syncStatus['operaciones_pendientes']?.toString() ?? '0',
                      Icons.sync,
                    ),
                    Divider(),
                    _buildStatusItem(
                      'Última sincronización',
                      _syncStatus['ultima_sincronizacion'] != null 
                          ? _formatDate(_syncStatus['ultima_sincronizacion'])
                          : 'Nunca',
                      Icons.access_time,
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSyncing ? null : _performSync,
                icon: _isSyncing 
                    ? CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    : Icon(Icons.sync),
                label: Text(_isSyncing ? 'Sincronizando...' : 'Sincronizar Ahora'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
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
                    'Los datos se sincronizan automáticamente cuando hay conexión a internet',
                    Icons.wifi,
                  ),
                  _buildInfoCard(
                    'Modo Offline',
                    'Puedes trabajar sin conexión y los datos se sincronizarán después',
                    Icons.offline_bolt,
                  ),
                  _buildInfoCard(
                    'Datos Seguros',
                    'Toda la información se encripta durante la sincronización',
                    Icons.security,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(String title, String value, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(title),
      trailing: Text(value, style: TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildInfoCard(String title, String subtitle, IconData icon) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: Colors.green),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
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