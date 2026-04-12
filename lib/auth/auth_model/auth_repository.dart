import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import '../auth_model/user_model.dart';
import 'dart:convert';


class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<UserCredential> login(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception('Error al iniciar sesión: $e');
    }
  }

  Future<String> subirImagenBase64(String uid, File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      String base64Image = base64Encode(bytes);
      String dataUrl = "data:image/jpeg;base64,$base64Image";

      // LOG DE SEGURIDAD: Si esto mide más de 1,000,000, va a fallar.
      debugPrint("Tamaño del Base64: ${dataUrl.length} caracteres");

      await _firestore.collection('users').doc(uid).update({
        'fotoUrl': dataUrl,
      });

      return dataUrl;
    } catch (e) {
      throw 'Error en Firestore: $e';
    }
  }

  Future<UserModel> register({
    required String nombre,
    required String apellidoPaterno,
    required String apellidoMaterno,
    required String correo,
    required String contrasena,
    required String role,
  }) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: correo,
      password: contrasena,
    );

    final user = UserModel(
      id: userCredential.user!.uid,
      nombre: nombre,
      apellidoPaterno: apellidoPaterno,
      apellidoMaterno: apellidoMaterno,
      correo: correo,
      role: role,
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection('users')
        .doc(userCredential.user!.uid)
        .set(user.toFirestore());

    return user;
  }

  Future<String?> getUserRole(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    return doc.exists ? (doc.get('role') as String?) : null;
  }

  Future<void> actualizarPerfil({
    required String userId,
    String? telefono,
    String? domicilio,
  }) async {
    final Map<String, dynamic> datos = {};
    if (telefono != null) datos['telefono'] = telefono;
    if (domicilio != null) datos['domicilio'] = domicilio;

    if (datos.isNotEmpty) {
      await _firestore.collection('users').doc(userId).update(datos);
    }
  }
}