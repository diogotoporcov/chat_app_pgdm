import "package:cloud_firestore/cloud_firestore.dart";

class User {
  final String uid;
  final String email;
  final String username;
  final String? profilePictureUrl;
  final String? statusMessage;
  final DateTime createdAt;

  User({
    required this.uid,
    required this.email,
    required this.username,
    this.profilePictureUrl,
    this.statusMessage,
    required this.createdAt,
  });

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      uid: map["uid"],
      email: map["email"],
      username: map["username"],
      profilePictureUrl: map["profilePictureUrl"],
      statusMessage: map["statusMessage"],
      createdAt: (map["createdAt"] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "uid": uid,
      "email": email,
      "username": username,
      "profilePictureUrl": profilePictureUrl,
      "statusMessage": statusMessage,
      "createdAt": createdAt,
    };
  }
}
