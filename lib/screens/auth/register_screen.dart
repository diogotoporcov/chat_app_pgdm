import "package:firebase_auth/firebase_auth.dart" as fb;
import "package:flutter/cupertino.dart";
import "../../services/auth_service.dart";

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _authService = AuthService();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;

  void _register() async {
    final email = _emailController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || username.isEmpty || password.isEmpty) {
      _showError("Por favor, preencha todos os campos.");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final fbUser = await _authService.signUp(email, password);
      if (fbUser != null) {
        await _authService.createUserInFirestore(fbUser, username);
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed("/home");
      } else {
        _showError("Erro desconhecido ao criar usuário.");
      }
    } on fb.FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case "email-already-in-use":
          msg = "Este email já está em uso.";
          break;
        case "invalid-email":
          msg = "Email inválido.";
          break;
        case "weak-password":
          msg = "Senha muito fraca.";
          break;
        default:
          msg = "Erro: ${e.message}";
      }
      _showError(msg);
    } catch (e) {
      String msg = "Erro ao cadastrar: ${e.toString()}";
      if (e.toString().contains("Nome de usuário já está em uso")) {
        msg = "Nome de usuário já está em uso.";
      }
      _showError(msg);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: const Text("Erro"),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              child: const Text("OK"),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text("Cadastro"),
      ),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  CupertinoTextField(
                    controller: _emailController,
                    placeholder: "Email",
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    autofocus: true,
                    clearButtonMode: OverlayVisibilityMode.editing,
                    onSubmitted: (_) => _register(),
                  ),
                  const SizedBox(height: 12),
                  CupertinoTextField(
                    controller: _usernameController,
                    placeholder: "Nome de usuário",
                    autocorrect: false,
                    clearButtonMode: OverlayVisibilityMode.editing,
                    onSubmitted: (_) => _register(),
                  ),
                  const SizedBox(height: 12),
                  CupertinoTextField(
                    controller: _passwordController,
                    placeholder: "Senha",
                    obscureText: true,
                    clearButtonMode: OverlayVisibilityMode.editing,
                    onSubmitted: (_) => _register(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      onPressed: _isLoading ? null : _register,
                      child: _isLoading
                          ? const CupertinoActivityIndicator()
                          : const Text("Cadastrar"),
                    ),
                  ),
                  const SizedBox(height: 16),
                  CupertinoButton(
                    child: const Text("Já tem uma conta? Fazer Login"),
                    onPressed: () {
                      Navigator.of(context).pushReplacementNamed("/login");
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
