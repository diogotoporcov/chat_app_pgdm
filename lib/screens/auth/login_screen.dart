import "package:flutter/cupertino.dart";
import "../../services/auth_service.dart";
import "package:firebase_auth/firebase_auth.dart" as fb;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;

  void _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showError("Por favor, preencha todos os campos.");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final fb.User? fbUser = await _authService.signIn(email, password);
      if (fbUser != null) {
        if (!mounted) return;
        Navigator.of(context).pushNamed("/home");
      } else {
        _showError("Usuário ou senha inválidos.");
      }
    } on fb.FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case "user-not-found":
          msg = "Usuário não encontrado.";
          break;
        case "wrong-password":
          msg = "Senha incorreta.";
          break;
        case "invalid-email":
          msg = "Email inválido.";
          break;
        case "user-disabled":
          msg = "Usuário desabilitado.";
          break;
        default:
          msg = "Erro: ${e.message}";
      }
      _showError(msg);
    } catch (e) {
      _showError("Erro no login: ${e.toString()}");
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
    final user = fb.FirebaseAuth.instance.currentUser;
    if (user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed("/home");
      });
      return const CupertinoPageScaffold(
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text("Login"),
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
                    onSubmitted: (_) => _login()
                  ),
                  const SizedBox(height: 12),
                  CupertinoTextField(
                    controller: _passwordController,
                    placeholder: "Senha",
                    obscureText: true,
                    clearButtonMode: OverlayVisibilityMode.editing,
                    onSubmitted: (_) => _login()
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      onPressed: _isLoading ? null : _login,
                      child: _isLoading
                          ? const CupertinoActivityIndicator()
                          : const Text("Entrar"),
                    ),
                  ),
                  const SizedBox(height: 16),
                  CupertinoButton(
                    child: const Text("Ainda não tem conta? Cadastrar"),
                    onPressed: () {
                      Navigator.of(context).pushReplacementNamed("/register");
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
