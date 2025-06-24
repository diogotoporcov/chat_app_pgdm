import "package:firebase_auth/firebase_auth.dart" as fb;
import "package:cloud_firestore/cloud_firestore.dart";
import "../config/app_config.dart";
import "../models/user.dart";

class AuthService {
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;

  Future<fb.User?> signUp(String email, String password) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return result.user;
  }

  Future<void> createUserInFirestore(fb.User firebaseUser, String username) async {
    final firestore = FirebaseFirestore.instance;
    final userDoc = firestore.collection("users").doc(firebaseUser.uid);
    final usernameRef = firestore.collection("usernames").doc(username);

    // Verifica se o username já está em uso
    final usernameSnapshot = await usernameRef.get();
    if (usernameSnapshot.exists) {
      throw Exception("Nome de usuário já está em uso.");
    }

    final newUser = User(
      uid: firebaseUser.uid,
      email: firebaseUser.email ?? "",
      username: username,
      profilePictureUrl: null,
      statusMessage: AppConfig.defaultStatusMessage,
      createdAt: DateTime.now(),
    );

    // Transação para garantir a unicidade
    await firestore.runTransaction((transaction) async {
      transaction.set(usernameRef, {"uid": firebaseUser.uid});
      transaction.set(userDoc, newUser.toMap());
    });
  }

  Future<fb.User?> signIn(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return result.user;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  fb.User? get currentUser => _auth.currentUser;
}

// Função auxiliar para carregar usuário a partir do Firestore
Future<User?> fetchUserFromFirestore(String uid) async {
  final doc = await FirebaseFirestore.instance.collection("users").doc(uid).get();

  if (doc.exists && doc.data() != null) {
    return User.fromMap(doc.data()!);
  }

  return null;
}

Future<User?> fetchUserByUsername(String username) async {
  try {
    final usernameDoc = await FirebaseFirestore.instance.collection("usernames").doc(username).get();

    if (!usernameDoc.exists || usernameDoc.data() == null) {
      return null;
    }

    final uid = usernameDoc.data()!["uid"] as String;
    return await fetchUserFromFirestore(uid);
  } catch (e) {
    return null;
  }
}

Future<void> saveFcmToken(String uid, String? token) async {
  if (token == null) return;

  await FirebaseFirestore.instance.collection("users").doc(uid).update({
    "fcmToken": token,
  });
}
