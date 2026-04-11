import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth_model/user_model.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<UserModel> login(String email, String password) async {
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final userDoc = await _firestore
        .collection('users')
        .doc(userCredential.user!.uid)
        .get();

    return UserModel.fromFirestore(userDoc, userCredential.user!.uid);
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
    return doc.get('role') as String?;
  }

  // Actualiza teléfono y/o domicilio del usuario en Firestore
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