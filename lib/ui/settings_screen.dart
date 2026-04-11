import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../auth/auth_ui/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _nombre = '';
  String _correo = '';
  String _role = '';
  String _telefono = '';
  String _domicilio = '';
  bool _cargando = true;
  bool _cargandoDomicilio = false;

  @override
  void initState() {
    super.initState();
    _cargarDatosUsuario();
  }

  Future<void> _cargarDatosUsuario() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data();
      if (data != null && mounted) {
        setState(() {
          _nombre =
              '${data['nombre'] ?? ''} ${data['apellidoPaterno'] ?? ''} ${data['apellidoMaterno'] ?? ''}'
                  .trim();
          _correo = data['correo'] ?? _auth.currentUser?.email ?? '';
          _role = data['role'] ?? 'usuario';
          _telefono = data['telefono'] ?? '';
          _domicilio = data['domicilio'] ?? '';
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _cerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cerrar sesión',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await _auth.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
        );
      }
    }
  }

  Future<void> _obtenerDomicilioGPS() async {
    setState(() => _cargandoDomicilio = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _mostrarMensaje('Por favor activa la ubicación', error: true);
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        _mostrarMensaje('Permiso de ubicación denegado', error: true);
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final partes = <String>[];
        if ((p.subLocality ?? '').isNotEmpty) partes.add(p.subLocality!);
        if ((p.locality ?? '').isNotEmpty) partes.add(p.locality!);
        if ((p.administrativeArea ?? '').isNotEmpty) {
          partes.add(p.administrativeArea!);
        }
        final domicilio = partes.join(', ');
        if (domicilio.isNotEmpty) {
          setState(() => _domicilio = domicilio);
          await _guardarCampo('domicilio', domicilio);
          _mostrarMensaje('Domicilio actualizado');
        }
      }
    } catch (e) {
      _mostrarMensaje('Error al obtener ubicación', error: true);
    } finally {
      if (mounted) setState(() => _cargandoDomicilio = false);
    }
  }

  Future<void> _guardarCampo(String campo, String valor) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('users').doc(uid).update({campo: valor});
  }

  void _mostrarMensaje(String mensaje, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(mensaje),
      backgroundColor: error ? Colors.red : Colors.green,
    ));
  }

  void _editarTelefono() {
    final controller = TextEditingController(text: _telefono);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar teléfono'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 10,
          decoration: const InputDecoration(
            hintText: 'Ej: 2351234567',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.phone),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final valor = controller.text.trim();
              Navigator.pop(context);
              if (valor.isNotEmpty) {
                setState(() => _telefono = valor);
                await _guardarCampo('telefono', valor);
                _mostrarMensaje('Teléfono actualizado');
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: _cerrarSesion,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Tarjeta perfil ─────────────────────────────────────
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.blue.shade100,
                    child: Icon(
                      _role == 'admin'
                          ? Icons.admin_panel_settings
                          : Icons.person,
                      size: 36,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _nombre.isEmpty ? 'Usuario' : _nombre,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _correo,
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: _role == 'admin'
                                ? Colors.orange.shade100
                                : Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _role == 'admin'
                                ? 'Administrador'
                                : 'Ciudadano',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _role == 'admin'
                                  ? Colors.orange.shade800
                                  : Colors.blue.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Sección Cuenta ─────────────────────────────────────
          _seccionTitulo('Cuenta'),
          _itemAjuste(
            icon: Icons.email_outlined,
            titulo: 'Correo electrónico',
            subtitulo: _correo.isEmpty ? 'Sin correo' : _correo,
            onTap: null,
          ),
          _itemAjuste(
            icon: Icons.phone_outlined,
            titulo: 'Teléfono',
            subtitulo:
            _telefono.isEmpty ? 'Toca para agregar' : _telefono,
            subtituloColor:
            _telefono.isEmpty ? Colors.blue : Colors.grey[600],
            trailing: const Icon(Icons.edit, size: 18, color: Colors.blue),
            onTap: _editarTelefono,
          ),
          _itemAjuste(
            icon: Icons.location_on_outlined,
            titulo: 'Colonia / Municipio',
            subtitulo: _cargandoDomicilio
                ? 'Obteniendo ubicación...'
                : _domicilio.isEmpty
                ? 'Toca para detectar'
                : _domicilio,
            subtituloColor:
            _domicilio.isEmpty ? Colors.blue : Colors.grey[600],
            trailing: _cargandoDomicilio
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.my_location,
                size: 18, color: Colors.blue),
            onTap: _cargandoDomicilio ? null : _obtenerDomicilioGPS,
          ),
          _itemAjuste(
            icon: Icons.badge_outlined,
            titulo: 'Rol',
            subtitulo: _role == 'admin' ? 'Administrador' : 'Ciudadano',
            onTap: null,
          ),
        ],
      ),
    );
  }

  Widget _seccionTitulo(String titulo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        titulo.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey[500],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _itemAjuste({
    required IconData icon,
    required String titulo,
    required String subtitulo,
    Color? subtituloColor,
    Widget? trailing,
    required VoidCallback? onTap,
  }) {
    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title:
        Text(titulo, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(
          subtitulo,
          style: TextStyle(
              color: subtituloColor ?? Colors.grey[600], fontSize: 13),
        ),
        trailing: trailing ??
            (onTap != null
                ? const Icon(Icons.chevron_right, color: Colors.grey)
                : null),
        onTap: onTap,
      ),
    );
  }
}