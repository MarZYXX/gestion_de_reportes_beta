import 'package:cloud_firestore/cloud_firestore.dart';

class ComentarioModel {
  final String id;
  final String userId;
  final String texto;
  final DateTime fecha;

  ComentarioModel({
    required this.id,
    required this.userId,
    required this.texto,
    required this.fecha,
  });

  factory ComentarioModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ComentarioModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      texto: data['texto'] ?? '',
      fecha: (data['fecha'] as Timestamp).toDate(),
    );
  }
}