import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'map_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';

class RegisteredUserScreen extends StatefulWidget {
  const RegisteredUserScreen({super.key});

  @override
  State<RegisteredUserScreen> createState() => _RegisteredUserScreenState();
}

class _RegisteredUserScreenState extends State<RegisteredUserScreen> {
  int _indiceSeleccionado = 0;
  DateTime? _ultimoBackPress;

  final List<Widget> _pantallas = [
    const MapScreen(),
    const ReportsScreen(),
    const SettingsScreen(),
  ];

  Future<bool> _onWillPop() async {
    if (_indiceSeleccionado != 0) {
      setState(() => _indiceSeleccionado = 0);
      return false;
    }
    final ahora = DateTime.now();
    if (_ultimoBackPress == null ||
        ahora.difference(_ultimoBackPress!) > const Duration(seconds: 2)) {
      _ultimoBackPress = ahora;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Presiona atrás de nuevo para salir'),
          duration: Duration(seconds: 2),
        ),
      );
      return false;
    }
    await SystemNavigator.pop();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) await _onWillPop();
      },
      child: Scaffold(
        body: IndexedStack(
          index: _indiceSeleccionado,
          children: _pantallas,
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _indiceSeleccionado,
          onTap: (index) => setState(() => _indiceSeleccionado = index),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.blue,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Mapa'),
            BottomNavigationBarItem(
                icon: Icon(Icons.list_alt), label: 'Mis Reportes'),
            BottomNavigationBarItem(
                icon: Icon(Icons.settings), label: 'Ajustes'),
          ],
        ),
      ),
    );
  }
}