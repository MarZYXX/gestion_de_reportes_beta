import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../auth/auth_ui/login_screen.dart';
import '../viewmodel/reportes_viewmodel.dart';
import '../model/report_model.dart';
import 'crear_reporte_screen.dart';

enum OpcionesMenu { editar, eliminar }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ReportesViewModel>(context, listen: false)
          .cambiarFiltro('todos');
    });
  }

  Future<void> _cerrarSesion(BuildContext context) async {
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
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
        );
      }
    }
  }

  void _confirmarEliminacion(String reportId, ReportesViewModel vm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar reporte'),
        content: const Text('¿Estás seguro de que deseas eliminar este reporte? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              vm.eliminarReporteLocal(reportId);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reporte eliminado'), backgroundColor: Colors.red),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _abrirDetalleEdicion(BuildContext context, ReporteModel reporte) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CrearReporteScreen(reporteOriginal: reporte),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => _cerrarSesion(context),
          ),
        ],
      ),
      body: Consumer<ReportesViewModel>(
        builder: (context, vm, child) {
          if (vm.cargando) return const Center(child: CircularProgressIndicator());
          if (vm.error != null) return Center(child: Text('Error: ${vm.error}', style: const TextStyle(color: Colors.red)));

          final reportesMostrar = vm.reportesFiltrados;

          return Column(
            children: [
              // --- SECCIÓN DE FILTROS ---
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: Colors.grey.shade50,
                width: double.infinity,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Icon(Icons.filter_list, color: Colors.grey, size: 20),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Atendidos'),
                        selected: vm.mostrarSoloAtendidos,
                        selectedColor: Colors.green.shade100,
                        onSelected: (val) => vm.toggleMostrarAtendidos(val),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Mis reportes'),
                        selected: vm.filtroActual == 'mis_reportes',
                        selectedColor: Colors.blue.shade100,
                        onSelected: (val) => vm.cambiarFiltro(val ? 'mis_reportes' : 'todos'),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Alta'),
                        selected: vm.filtroPrioridadLocal == 'alta',
                        selectedColor: Colors.red.shade100,
                        onSelected: (val) => vm.setFiltroPrioridadLocal(val ? 'alta' : 'todas'),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Media'),
                        selected: vm.filtroPrioridadLocal == 'media',
                        selectedColor: Colors.orange.shade100,
                        onSelected: (val) => vm.setFiltroPrioridadLocal(val ? 'media' : 'todas'),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Baja'),
                        selected: vm.filtroPrioridadLocal == 'baja',
                        selectedColor: Colors.blue.shade100,
                        onSelected: (val) => vm.setFiltroPrioridadLocal(val ? 'baja' : 'todas'),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),

              // --- LISTA DE REPORTES ---
              Expanded(
                child: reportesMostrar.isEmpty
                    ? const Center(
                  child: Text('No hay reportes que coincidan con los filtros.',
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                )
                    : RefreshIndicator(
                  onRefresh: () async => await vm.cargarReportes(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: reportesMostrar.length,
                    itemBuilder: (context, index) {
                      final ReporteModel reporte = reportesMostrar[index];
                      final bool esPropio = reporte.userId == currentUserId;

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: reporte.getColorSeveridad().withOpacity(0.5), width: 1),
                        ),
                        child: ListTile(
                          onTap: esPropio ? () => _abrirDetalleEdicion(context, reporte) : null,
                          contentPadding: const EdgeInsets.all(16),
                          title: Text(
                            reporte.titulo,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          // TRES PUNTITOS PARA EDITAR/ELIMINAR - SOLO SI ES PROPIO (MISMO USUARIO PUEDE EDITAR SUS REPORTES, NO DE OTROS)
                          trailing: esPropio ? PopupMenuButton<OpcionesMenu>(
                            icon: const Icon(Icons.more_vert, color: Colors.grey),
                            onSelected: (opcion) {
                              if (opcion == OpcionesMenu.eliminar) {
                                _confirmarEliminacion(reporte.id, vm);
                              } else if (opcion == OpcionesMenu.editar) {
                                _abrirDetalleEdicion(context, reporte);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: OpcionesMenu.editar,
                                child: Row(children: [Icon(Icons.edit, color: Colors.blue), SizedBox(width: 8), Text('Editar')]),
                              ),
                              const PopupMenuItem(
                                value: OpcionesMenu.eliminar,
                                child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text('Eliminar')]),
                              ),
                            ],
                          ) : null,
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              Text(reporte.descripcion, maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    DateFormat('dd/MM/yyyy').format(reporte.fechaIncidente),
                                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                  ),
                                  const Spacer(),
                                  if (reporte.estaCompleto)
                                    Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)),
                                      child: const Text('Atendido', style: TextStyle(color: Colors.white, fontSize: 10)),
                                    ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: reporte.getColorSeveridad().withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      reporte.getTextoSeveridad(),
                                      style: TextStyle(color: reporte.getColorSeveridad(), fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}