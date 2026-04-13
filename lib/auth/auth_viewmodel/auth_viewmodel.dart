import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../auth_model/auth_repository.dart';
import '../auth_model/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthRepository _repository = AuthRepository();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void _setCurrentUser(UserModel? user) {
    _currentUser = user;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _setError(null);

    try {
      final userCredential = await _repository.login(email, password);
      final String uid = userCredential.user!.uid;

      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (doc.exists) {
        final userModel = UserModel.fromFirestore(doc, uid);
        _setCurrentUser(userModel);
      } else {
        _setError('Datos de usuario no encontrados');
        return false;
      }

      return true;
    } catch (e) {
      _setError(_mapLoginError(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  String _mapLoginError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return 'User not found';
        case 'wrong-password':
          return 'Incorrect password';
        case 'invalid-email':
          return 'Invalid email';
        default:
          return 'Login failed';
      }
    }
    return 'Something went wrong';
  }

  Future<bool> register({
    required String nombre,
    required String apellidoPaterno,
    required String apellidoMaterno,
    required String correo,
    required String contrasena,
    required String role,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      final user = await _repository.register(
        nombre: nombre,
        apellidoPaterno: apellidoPaterno,
        apellidoMaterno: apellidoMaterno,
        correo: correo,
        contrasena: contrasena,
        role: role,
      );
      _setCurrentUser(user);
      return true;
    } catch (e) {
      _setError(_mapRegisterError(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  String _mapRegisterError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'Email already in use';
        case 'invalid-email':
          return 'Invalid email';
        case 'weak-password':
          return 'Password is too weak';
        default:
          return 'Registration failed';
      }
    }
    return 'Something went wrong';
  }

  Future<String?> getUserRole(String userId) async {
    return await _repository.getUserRole(userId);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}