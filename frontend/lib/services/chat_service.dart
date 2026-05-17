import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_model.dart';

final chatServiceProvider = Provider<ChatService>((ref) => ChatService());

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage   _storage   = FirebaseStorage.instance;

  // ── Chat rooms ────────────────────────────────────────────────────────────

  Stream<List<ChatRoom>> getChatRooms(String userId) {
    return _firestore
        .collection('chatRooms')
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ChatRoom.fromFirestore(d)).toList());
  }

  Future<ChatRoom> createChatRoom({
    required String name,
    required List<String> participantIds,
  }) async {
    final doc = await _firestore.collection('chatRooms').add({
      'name': name,
      'participants': participantIds,
      'lastMessage': null,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadCount': {for (final id in participantIds) id: 0},
      'imageUrl': null,
    });
    final snap = await doc.get();
    return ChatRoom.fromFirestore(snap);
  }

  // ── Messages ──────────────────────────────────────────────────────────────

  Stream<List<ChatMessage>> getChatMessages(String roomId) {
    return _firestore
        .collection('chatRooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ChatMessage.fromFirestore(d)).toList());
  }

  Future<void> sendMessage({
    required String roomId,
    required String senderId,
    required String content,
    List<int>? imageBytes,        // platform-neutral bytes instead of dart:io File
    String? imageMimeType,
  }) async {
    String? imageUrl;

    if (imageBytes != null) {
      final ref = _storage
          .ref()
          .child('chat_images/$roomId/${DateTime.now().millisecondsSinceEpoch}');
      final metadata = SettableMetadata(
          contentType: imageMimeType ?? 'image/jpeg');
      await ref.putData(
          Uint8List.fromList(imageBytes), metadata);
      imageUrl = await ref.getDownloadURL();
    }

    final message = {
      'senderId': senderId,
      'content': content,
      'timestamp': FieldValue.serverTimestamp(),
      'imageUrl': imageUrl,
      'isRead': false,
    };

    final batch = _firestore.batch();

    // Add message to sub-collection
    final msgRef = _firestore
        .collection('chatRooms')
        .doc(roomId)
        .collection('messages')
        .doc();
    batch.set(msgRef, message);

    // Update room last-message metadata
    batch.update(_firestore.collection('chatRooms').doc(roomId), {
      'lastMessage': imageUrl != null ? '📷 Photo' : content,
      'lastMessageTime': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> markAsRead(String roomId, String userId) async {
    await _firestore.collection('chatRooms').doc(roomId).update({
      'unreadCount.$userId': 0,
    });
  }
}
