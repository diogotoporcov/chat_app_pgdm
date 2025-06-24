import 'package:flutter/cupertino.dart';
import 'package:chat_app_pgdm/services/auth_service.dart';
import 'package:chat_app_pgdm/models/user.dart' as app_user;
import 'package:chat_app_pgdm/config/app_config.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io' show File;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class ProfileScreen extends StatefulWidget {
  final String uid;

  const ProfileScreen({super.key, required this.uid});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  app_user.User? _user;
  bool _loading = true;
  bool _isEditing = false;
  final AuthService _authService = AuthService();

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _statusMessageController = TextEditingController();

  XFile? _pickedXFile;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _statusMessageController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = await fetchUserFromFirestore(widget.uid);
    if (mounted) {
      setState(() {
        _user = user;
        _loading = false;
        if (_user != null) {
          _usernameController.text = _user!.username;
          _statusMessageController.text =
              _user!.statusMessage ?? AppConfig.defaultStatusMessage;
        }
      });
    }
  }


  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing && _user != null) {
        _usernameController.text = _user!.username;
        _statusMessageController.text =
            _user!.statusMessage ?? AppConfig.defaultStatusMessage;
        _pickedXFile = null;
      }
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _pickedXFile = pickedFile;
      });
    }
  }

  Future<String?> _uploadImage(XFile imageXFile) async {
    try {
      final Uint8List originalBytes = await imageXFile.readAsBytes();
      if (originalBytes.isEmpty) return null;

      final decodedImage = img.decodeImage(originalBytes);
      if (decodedImage == null) return null;

      final Uint8List jpgBytes = Uint8List.fromList(
        img.encodeJpg(decodedImage, quality: 85),
      );

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_pictures')
          .child('${_user!.uid}.jpg');

      final uploadTask = storageRef.putData(
        jpgBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final snapshot = await uploadTask.whenComplete(() => null);
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveProfile() async {
    if (_user == null) return;

    setState(() {
      _loading = true;
    });

    try {
      final newUsername = _usernameController.text.trim();
      final newStatus = _statusMessageController.text.trim();

      String? newProfilePictureUrl = _user!.profilePictureUrl;
      if (_pickedXFile != null) {
        newProfilePictureUrl = await _uploadImage(_pickedXFile!);
        if (newProfilePictureUrl == null) {
          throw Exception("Falha ao fazer upload da nova foto de perfil.");
        }
      }

      final batch = FirebaseFirestore.instance.batch();
      final userRef = FirebaseFirestore.instance.collection("users").doc(_user!.uid);
      final oldUsernameRef = FirebaseFirestore.instance.collection("usernames").doc(_user!.username);
      final newUsernameRef = FirebaseFirestore.instance.collection("usernames").doc(newUsername);

      if (newUsername != _user!.username) {
        final newUsernameDoc = await newUsernameRef.get();
        if (newUsernameDoc.exists) {
          throw Exception("Nome de usuário já está em uso.");
        }

        batch.set(newUsernameRef, {"uid": _user!.uid});
        batch.delete(oldUsernameRef);
      }

      batch.update(userRef, {
        "username": newUsername,
        "statusMessage": newStatus,
        "profilePictureUrl": newProfilePictureUrl,
      });

      await batch.commit();
      await _loadUser();

      setState(() {
        _isEditing = false;
        _pickedXFile = null;
      });

      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text("Sucesso"),
            content: const Text("Perfil atualizado!"),
            actions: [
              CupertinoDialogAction(
                child: const Text("OK"),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text("Erro"),
            content: Text(
              e.toString().contains("Nome de usuário já está em uso")
                  ? "Nome de usuário já está em uso."
                  : "Falha ao atualizar perfil: ${e.toString()}",
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text("OK"),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = fb_auth.FirebaseAuth.instance.currentUser;
    final isMyProfile = currentUser?.uid == widget.uid;
    void logout() {
      showCupertinoModalPopup(
        context: context,
        builder: (ctx) => CupertinoActionSheet(
          title: const Text("Deseja realmente sair?"),
          actions: [
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () async {
                Navigator.of(ctx).pop(); // Fecha o ActionSheet
                final currentContext = context; // Capture the context before the async gap
                await _authService.signOut();
                if (currentContext.mounted) { // Check the captured context's mounted status
                  Navigator.of(currentContext).pushReplacementNamed("/");
                }
              },
              child: const Text("Sair da conta"),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Cancelar"),
          ),
        ),
      );
    }
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(_loading ? "Carregando..." : "Perfil de ${_user?.username ?? ''}"),
        trailing: isMyProfile
            ? _isEditing
            ? CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _saveProfile,
          child: _loading
              ? const CupertinoActivityIndicator()
              : const Text("Salvar"),
        )
            : CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _toggleEditMode,
          child: const Icon(CupertinoIcons.pencil),
        )
            : null,
      ),
      child: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : _user == null
          ? const Center(child: Text("Usuário não encontrado"))
          : SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Align(
                alignment: Alignment.topCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MouseRegion(
                      cursor: _isEditing && isMyProfile
                          ? SystemMouseCursors.click
                          : MouseCursor.defer,
                      child: GestureDetector(
                        onTap: _isEditing && isMyProfile ? _pickImage : null,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: CupertinoColors.systemGrey5,
                                image: _pickedXFile != null && !kIsWeb
                                    ? DecorationImage(
                                  image: FileImage(File(_pickedXFile!.path)),
                                  fit: BoxFit.cover,
                                )
                                    : (_user!.profilePictureUrl != null &&
                                    _user!.profilePictureUrl!.isNotEmpty &&
                                    _pickedXFile == null)
                                    ? DecorationImage(
                                  image: NetworkImage(_user!.profilePictureUrl!),
                                  fit: BoxFit.cover,
                                )
                                    : null,
                              ),
                              child: _pickedXFile == null &&
                                  (_user!.profilePictureUrl == null ||
                                      _user!.profilePictureUrl!.isEmpty)
                                  ? const Icon(CupertinoIcons.person, size: 50)
                                  : (_pickedXFile != null && kIsWeb)
                                  ? FutureBuilder<Uint8List>(
                                future: _pickedXFile!.readAsBytes(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.done &&
                                      snapshot.hasData) {
                                    return ClipOval(
                                      child: Image.memory(
                                        snapshot.data!,
                                        fit: BoxFit.cover,
                                        width: 100,
                                        height: 100,
                                      ),
                                    );
                                  } else if (snapshot.hasError) {
                                    return const Icon(
                                        CupertinoIcons.exclamationmark_triangle,
                                        size: 50);
                                  }
                                  return const CupertinoActivityIndicator();
                                },
                              )
                                  : null,
                            ),
                            if (_isEditing && isMyProfile)
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: CupertinoColors.black.withValues(alpha: 0.4),
                                ),
                                child: const Icon(
                                  CupertinoIcons.camera_fill,
                                  color: CupertinoColors.white,
                                  size: 40,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _isEditing
                        ? CupertinoTextField(
                      controller: _usernameController,
                      placeholder: "Nome de usuário",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      clearButtonMode: OverlayVisibilityMode.editing,
                    )
                        : Text(
                      _user!.username,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (isMyProfile)
                      Text(
                        _user!.email,
                        style: const TextStyle(
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                    const SizedBox(height: 16),
                    _isEditing
                        ? CupertinoTextField(
                      controller: _statusMessageController,
                      placeholder: "Mensagem de status",
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontStyle: FontStyle.italic),
                      clearButtonMode: OverlayVisibilityMode.editing,
                    )
                        : Text(
                      _user!.statusMessage ??
                          AppConfig.defaultStatusMessage,
                      style: const TextStyle(fontStyle: FontStyle.italic),
                      textAlign: TextAlign.center,
                    ),
                    if (isMyProfile)
                      Column(
                        children: [
                          const SizedBox(height: 30),
                          CupertinoButton(
                            onPressed: logout,
                            child: const Text(
                              "Sair",
                              style: TextStyle(color: CupertinoColors.systemRed),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
