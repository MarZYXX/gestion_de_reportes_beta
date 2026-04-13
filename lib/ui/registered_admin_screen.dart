import 'package:flutter/material.dart';
import 'admin_reports_screen.dart';
import 'admin_map_screen.dart';
import 'admin_profile_screen.dart';

class RegisteredAdminScreen extends StatefulWidget {
  const RegisteredAdminScreen({super.key});

  @override
  State<RegisteredAdminScreen> createState() => _RegisteredAdminScreenState();
}

class _RegisteredAdminScreenState extends State<RegisteredAdminScreen> {
  int _indiceActual = 0;

  final List<Widget> _pantallas = [
    const AdminReportsScreen(),
    const AdminMapScreen(),
    const AdminProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _pantallas[_indiceActual],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indiceActual,
        onTap: (index) {
          setState(() {
            _indiceActual = index;
          });
        },
        selectedItemColor: Colors.blue.shade800,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'Reportes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Mapa',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}