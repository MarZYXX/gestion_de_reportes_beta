import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import '../auth/auth_ui/login_screen.dart';
import '../auth/auth_model/auth_repository.dart';

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
  String _fotoUrl = '';
  bool _subiendoFoto = false;

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
          _nombre = '${data['nombre'] ?? ''} ${data['apellidoPaterno'] ?? ''} ${data['apellidoMaterno'] ?? ''}'.trim();
          _correo = data['correo'] ?? _auth.currentUser?.email ?? '';
          _role = data['role'] ?? 'usuario';
          _telefono = data['telefono'] ?? '';
          _domicilio = data['domicilio'] ?? '';
          _fotoUrl = data['fotoUrl'] ?? '';
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cerrar sesión', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await _auth.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
      }
    }
  }

  Future<void> _cambiarFotoPerfil() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Actualizar foto de perfil', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.blue),
                title: const Text('Galería'),
                onTap: () {
                  Navigator.of(context).pop();
                  _seleccionarImagen(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera, color: Colors.blue),
                title: const Text('Cámara'),
                onTap: () {
                  Navigator.of(context).pop();
                  _seleccionarImagen(ImageSource.camera);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _seleccionarImagen(ImageSource fuente) async {
    final picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: fuente, imageQuality: 40, maxWidth: 300, maxHeight: 300);
      if (image == null || !mounted) return;

      setState(() => _subiendoFoto = true);
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw 'No hay usuario autenticado';

      final file = File(image.path);
      if (!await file.exists()) throw 'El archivo de imagen no se encontró';

      final repo = AuthRepository();
      final urlBase64 = await repo.subirImagenBase64(uid, file);

      if (mounted) {
        setState(() => _fotoUrl = urlBase64);
        _mostrarMensaje('Foto de perfil actualizada');
      }
    } catch (e) {
      if (mounted) _mostrarMensaje('Error al procesar la foto: $e', error: true);
    } finally {
      if (mounted) setState(() => _subiendoFoto = false);
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
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) {
        _mostrarMensaje('Permiso de ubicación denegado', error: true);
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final partes = <String>[];
        if ((p.subLocality ?? '').isNotEmpty) partes.add(p.subLocality!);
        if ((p.locality ?? '').isNotEmpty) partes.add(p.locality!);
        if ((p.administrativeArea ?? '').isNotEmpty) partes.add(p.administrativeArea!);

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
          decoration: const InputDecoration(hintText: 'Ej: 2351234567', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
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

  void _cambiarCorreo() {
    final TextEditingController emailController = TextEditingController(text: _correo);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cambiar Correo Electrónico'),
        content: TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Nuevo Correo', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: () async {
              final nuevoCorreo = emailController.text.trim();
              if (nuevoCorreo.isEmpty || nuevoCorreo == _correo) return;

              try {
                await _auth.currentUser!.verifyBeforeUpdateEmail(nuevoCorreo);
                await _guardarCampo('correo', nuevoCorreo);

                setState(() => _correo = nuevoCorreo);
                if (context.mounted) {
                  Navigator.pop(context);
                  _mostrarMensaje('Correo actualizado correctamente');
                }
              } on FirebaseAuthException catch (e) {
                if (e.code == 'requires-recent-login') {
                  if (context.mounted) {
                    Navigator.pop(context);
                    _mostrarMensaje('Por seguridad, cierra sesión y vuelve a entrar para cambiar tu correo.', error: true);
                  }
                } else {
                  if (context.mounted) _mostrarMensaje('Error: ${e.message}', error: true);
                }
              }
            },
            child: const Text('Actualizar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _cambiarContrasena() {
    final TextEditingController passwordController = TextEditingController();
    final TextEditingController confirmPasswordController = TextEditingController();

    bool ocultarNueva = true;
    bool ocultarConfirmacion = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
            builder: (context, setStateDialog) {
              return AlertDialog(
                title: const Text('Cambiar Contraseña'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Ingresa tu nueva contraseña. Debe tener al menos 6 caracteres.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      obscureText: ocultarNueva,
                      decoration: InputDecoration(
                        labelText: 'Nueva Contraseña',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(ocultarNueva ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                          onPressed: () {
                            setStateDialog(() {
                              ocultarNueva = !ocultarNueva;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: ocultarConfirmacion,
                      decoration: InputDecoration(
                        labelText: 'Confirmar Contraseña',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(ocultarConfirmacion ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                          onPressed: () {
                            setStateDialog(() {
                              ocultarConfirmacion = !ocultarConfirmacion;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                    onPressed: () async {
                      final newPass = passwordController.text;
                      final confirmPass = confirmPasswordController.text;

                      if (newPass != confirmPass) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Las contraseñas no coinciden'), backgroundColor: Colors.red));
                        return;
                      }
                      if (newPass.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La contraseña debe tener mínimo 6 caracteres'), backgroundColor: Colors.red));
                        return;
                      }

                      try {
                        if (FirebaseAuth.instance.currentUser != null) {
                          await FirebaseAuth.instance.currentUser!.updatePassword(newPass);
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contraseña actualizada exitosamente', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
                          }
                        }
                      } on FirebaseAuthException catch (e) {
                        if (e.code == 'requires-recent-login') {
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('Por seguridad, debes cerrar sesión y volver a entrar para cambiar tu contraseña.', style: TextStyle(color: Colors.white)),
                              backgroundColor: Colors.orange,
                              duration: Duration(seconds: 4),
                            ));
                          }
                        } else {
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.message}'), backgroundColor: Colors.red));
                        }
                      }
                    },
                    child: const Text('Actualizar', style: TextStyle(color: Colors.white)),
                  ),
                ],
              );
            }
        );
      },
    );
  }

  Future<void> _guardarCampo(String campo, String valor) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('users').doc(uid).update({campo: valor});
  }

  void _mostrarMensaje(String mensaje, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje, style: const TextStyle(color: Colors.white)), backgroundColor: error ? Colors.orange.shade800 : Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.blue, width: 3),
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.blue.shade50,
                          backgroundImage: _fotoUrl.isNotEmpty
                              ? (_fotoUrl.contains(',') ? MemoryImage(base64Decode(_fotoUrl.split(',').last)) : (_fotoUrl.startsWith('http') ? NetworkImage(_fotoUrl) as ImageProvider : MemoryImage(base64Decode(_fotoUrl))))
                              : null,
                          child: _fotoUrl.isEmpty ? const Icon(Icons.person, size: 50, color: Colors.blue) : null,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: _subiendoFoto ? null : _cambiarFotoPerfil,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                            child: _subiendoFoto
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Ciudadano',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _nombre.isEmpty ? 'Usuario Civil' : _nombre,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 8),
                    child: Text('DATOS DE CUENTA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600, letterSpacing: 1.2)),
                  ),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.email_outlined, color: Colors.blue.shade700),
                          title: const Text('Correo electrónico'),
                          subtitle: Text(_correo.isEmpty ? 'Sin correo' : _correo),
                        ),
                        const Divider(height: 1, indent: 50),
                        ListTile(
                          leading: Icon(Icons.phone_outlined, color: Colors.blue.shade700),
                          title: const Text('Teléfono'),
                          subtitle: Text(_telefono.isEmpty ? 'Toca para agregar' : _telefono, style: TextStyle(color: _telefono.isEmpty ? Colors.blue : Colors.grey.shade600)),
                          trailing: const Icon(Icons.edit, color: Colors.grey, size: 20),
                          onTap: _editarTelefono,
                        ),
                        const Divider(height: 1, indent: 50),
                        ListTile(
                          leading: Icon(Icons.location_on_outlined, color: Colors.blue.shade700),
                          title: const Text('Colonia / Municipio'),
                          subtitle: Text(_cargandoDomicilio ? 'Obteniendo...' : (_domicilio.isEmpty ? 'Toca para detectar' : _domicilio), style: TextStyle(color: _domicilio.isEmpty ? Colors.blue : Colors.grey.shade600)),
                          trailing: _cargandoDomicilio
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.my_location, color: Colors.grey, size: 20),
                          onTap: _cargandoDomicilio ? null : _obtenerDomicilioGPS,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 8),
                    child: Text('AJUSTES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600, letterSpacing: 1.2)),
                  ),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.email, color: Colors.grey),
                          title: const Text('Cambiar correo electrónico'),
                          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                          onTap: _cambiarCorreo,
                        ),
                        const Divider(height: 1, indent: 50),
                        ListTile(
                          leading: const Icon(Icons.lock_outline, color: Colors.grey),
                          title: const Text('Cambiar contraseña'),
                          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                          onTap: _cambiarContrasena,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar Sesión', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  onPressed: _cerrarSesion,
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}