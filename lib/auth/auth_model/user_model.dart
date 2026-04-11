import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String nombre;
  final String apellidoPaterno;
  final String apellidoMaterno;
  final String correo;
  final String role;
  final DateTime createdAt;
  final String? telefono;
  final String? domicilio;

  UserModel({
    required this.id,
    required this.nombre,
    required this.apellidoPaterno,
    required this.apellidoMaterno,
    required this.correo,
    required this.role,
    required this.createdAt,
    this.telefono,
    this.domicilio,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc, String id) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: id,
      nombre: data['nombre'] ?? '',
      apellidoPaterno: data['apellidoPaterno'] ?? '',
      apellidoMaterno: data['apellidoMaterno'] ?? '',
      correo: data['correo'] ?? '',
      role: data['role'] ?? 'usuario',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      telefono: data['telefono'],
      domicilio: data['domicilio'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'nombre': nombre,
      'apellidoPaterno': apellidoPaterno,
      'apellidoMaterno': apellidoMaterno,
      'correo': correo,
      'role': role,
      'createdAt': Timestamp.fromDate(createdAt),
      if (telefono != null) 'telefono': telefono,
      if (domicilio != null) 'domicilio': domicilio,
    };
  }

  UserModel copyWith({
    String? telefono,
    String? domicilio,
  }) {
    return UserModel(
      id: id,
      nombre: nombre,
      apellidoPaterno: apellidoPaterno,
      apellidoMaterno: apellidoMaterno,
      correo: correo,
      role: role,
      createdAt: createdAt,
      telefono: telefono ?? this.telefono,
      domicilio: domicilio ?? this.domicilio,
    );
  }
}