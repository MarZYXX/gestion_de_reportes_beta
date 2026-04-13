import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import '../repo/reporte_service.dart';
import '../model/report_model.dart';

class CrearReporteScreen extends StatefulWidget {
  final ReporteModel? reporteOriginal;
  const CrearReporteScreen({super.key, this.reporteOriginal});

  @override
  State<CrearReporteScreen> createState() => _CrearReporteScreenState();
}

class _CrearReporteScreenState extends State<CrearReporteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();

  String _severidad = 'baja';
  DateTime _fechaIncidente = DateTime.now();
  TimeOfDay _horaIncidente = TimeOfDay.now();
  GeoPoint? _ubicacion;
  List<String> _urlsImagenes = [];
  bool _cargando = false;
  String? _error;

  final ImagePicker _imagePicker = ImagePicker();
  final ReporteService _reporteService = ReporteService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  void initState() {
    super.initState();

    if (widget.reporteOriginal != null) {
      _tituloController.text = widget.reporteOriginal!.titulo;
      _descripcionController.text = widget.reporteOriginal!.descripcion;
      _severidad = widget.reporteOriginal!.severidad;
      _fechaIncidente = widget.reporteOriginal!.fechaIncidente;
      _horaIncidente = widget.reporteOriginal!.horaIncidente;
      _ubicacion = widget.reporteOriginal!.ubicacion;
      _urlsImagenes = List.from(widget.reporteOriginal!.urlsImagenes);
    } else {
      _obtenerUbicacionActual();
    }
  }

  Future<void> _obtenerUbicacionActual() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _error = 'Por favor active la ubicación');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _error = 'Permiso de ubicación denegado permanentemente');
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _ubicacion = GeoPoint(position.latitude, position.longitude);
      });
    } catch (e) {
      setState(() => _error = 'Error al obtener ubicación: $e');
    }
  }

  Future<void> _seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaIncidente,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (fecha != null) {
      setState(() => _fechaIncidente = fecha);
    }
  }

  Future<void> _seleccionarHora() async {
    final hora = await showTimePicker(
      context: context,
      initialTime: _horaIncidente,
    );
    if (hora != null) {
      setState(() => _horaIncidente = hora);
    }
  }

  void _mostrarOpcionesImagen() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.blue),
                title: const Text('Tomar foto con cámara'),
                onTap: () {
                  Navigator.pop(context);
                  _capturarImagen(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.blue),
                title: const Text('Elegir de la galería'),
                onTap: () {
                  Navigator.pop(context);
                  _seleccionarDesdeGaleria();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _capturarImagen(ImageSource source) async {
    final XFile? imagen = await _imagePicker.pickImage(
      source: source,
      imageQuality: 50,
    );
    if (imagen != null) {
      setState(() {
        _urlsImagenes.add(imagen.path);
      });
    }
  }

  Future<void> _seleccionarDesdeGaleria() async {
    final List<XFile> imagenes = await _imagePicker.pickMultiImage(
      imageQuality: 50,
    );
    if (imagenes.isNotEmpty) {
      setState(() {
        _urlsImagenes.addAll(imagenes.map((img) => img.path));
      });
    }
  }

  void _verImagenPantallaCompleta(String rutaImagen) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.black87,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            alignment: Alignment.center,
            children: [
              InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: rutaImagen.startsWith('http')
                    ? Image.network(
                  rutaImagen,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  },
                )
                    : Image.file(
                  File(rutaImagen),
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
              Positioned(
                top: 40,
                right: 20,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<List<String>> _subirImagenes(List<String> rutasLocales) async {
    List<String> urlsSubidas = [];
    for (String ruta in rutasLocales) {
      if (ruta.startsWith('http')) {
        urlsSubidas.add(ruta);
        continue;
      }
      File file = File(ruta);
      String fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(ruta)}';
      try {
        TaskSnapshot snapshot = await _storage.ref('reportes/$fileName').putFile(file);
        String downloadUrl = await snapshot.ref.getDownloadURL();
        urlsSubidas.add(downloadUrl);
      } catch (e) {
        debugPrint('Error al subir imagen: $e');
      }
    }
    return urlsSubidas;
  }

  Future<void> _guardarReporte() async {
    if (!_formKey.currentState!.validate()) return;

    if (_ubicacion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Obteniendo ubicación, espere un momento...')),
      );
      return;
    }

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final userId = _auth.currentUser?.uid;

      List<String> urlsFinales = await _subirImagenes(_urlsImagenes);

      if (widget.reporteOriginal == null) {
        final reporte = ReporteModel(
          id: '',
          userId: userId!,
          titulo: _tituloController.text,
          descripcion: _descripcionController.text,
          severidad: _severidad,
          fechaIncidente: _fechaIncidente,
          horaIncidente: _horaIncidente,
          ubicacion: _ubicacion!,
          urlsImagenes: urlsFinales,
          contadorCorroboraciones: 0,
          corroboradoPor: [],
          estaCompleto: false,
          fechaCreacion: DateTime.now(),
          fechaCompletado: null,
          severidadModificadaPorAdmin: false,
        );
        await _reporteService.crearReporte(reporte);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reporte creado exitosamente')));
        }
      } else {
        await _reporteService.actualizarReporte(widget.reporteOriginal!.id, {
          'titulo': _tituloController.text,
          'descripcion': _descripcionController.text,
          'severidad': _severidad,
          'fechaIncidente': Timestamp.fromDate(_fechaIncidente),
          'horaHora': _horaIncidente.hour,
          'horaMinuto': _horaIncidente.minute,
          'urlsImagenes': urlsFinales,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reporte actualizado exitosamente')));
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.reporteOriginal == null ? 'Crear Nuevo Reporte' : 'Editar Reporte'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _cargando
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Subiendo reporte e imágenes...'),
          ],
        ),
      )
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _tituloController,
              decoration: const InputDecoration(
                labelText: 'Título del reporte',
                hintText: 'Ej: Bache en la calle',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor ingrese un título';
                }
                if (value.length < 5) {
                  return 'El título debe tener al menos 5 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _descripcionController,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                hintText: 'Describa el incidente en detalle...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 5,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor ingrese una descripción';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _severidad,
              decoration: const InputDecoration(
                labelText: 'Nivel de severidad',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.warning),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'baja',
                  child: Row(
                    children: [
                      Icon(Icons.circle, color: Colors.green, size: 16),
                      SizedBox(width: 8),
                      Text('Baja'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'media',
                  child: Row(
                    children: [
                      Icon(Icons.circle, color: Colors.orange, size: 16),
                      SizedBox(width: 8),
                      Text('Media'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'alta',
                  child: Row(
                    children: [
                      Icon(Icons.circle, color: Colors.red, size: 16),
                      SizedBox(width: 8),
                      Text('Alta'),
                    ],
                  ),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _severidad = value);
              },
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Fecha'),
                    subtitle: Text(
                      '${_fechaIncidente.day}/${_fechaIncidente.month}/${_fechaIncidente.year}',
                    ),
                    onTap: _seleccionarFecha,
                  ),
                ),
                Expanded(
                  child: ListTile(
                    leading: const Icon(Icons.access_time),
                    title: const Text('Hora'),
                    subtitle: Text(_horaIncidente.format(context)),
                    onTap: _seleccionarHora,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: _mostrarOpcionesImagen,
              icon: const Icon(Icons.add_photo_alternate),
              label: Text(
                _urlsImagenes.isEmpty
                    ? 'Agregar imágenes'
                    : '${_urlsImagenes.length} imagen(es) seleccionada(s)',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade200,
                foregroundColor: Colors.black,
              ),
            ),

            if (_urlsImagenes.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _urlsImagenes.length,
                  itemBuilder: (context, index) {
                    final imgPath = _urlsImagenes[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          GestureDetector(
                            onTap: () => _verImagenPantallaCompleta(imgPath),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: imgPath.startsWith('http')
                                  ? Image.network(
                                imgPath,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const SizedBox(
                                    width: 80,
                                    height: 80,
                                    child: Center(child: CircularProgressIndicator()),
                                  );
                                },
                              )
                                  : Image.file(
                                File(imgPath),
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _urlsImagenes.removeAt(index);
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 24),

            if (_ubicacion == null)
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text('Obteniendo ubicación actual...'),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.green),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ubicación actual obtenida correctamente',
                        style: TextStyle(color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _guardarReporte,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                widget.reporteOriginal == null ? 'CREAR REPORTE' : 'ACTUALIZAR REPORTE',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }
}