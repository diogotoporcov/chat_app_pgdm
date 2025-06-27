import "package:flutter/cupertino.dart";
import "package:firebase_auth/firebase_auth.dart" as fb;

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final fb.User? user = fb.FirebaseAuth.instance.currentUser; // Obtém o usuário Firebase atualmente logado
    // Se já estiver autenticado, redireciona automaticamente
    if (user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed("/home"); // Redireciona para a tela inicial se o usuário estiver logado
      });
      return const CupertinoPageScaffold(
        child: Center(child: CupertinoActivityIndicator()), // Exibe um indicador de atividade enquanto redireciona
      );
    }

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text("Seja Bem-vindo"), // Título da barra de navegação
        automaticallyImplyLeading: false, // Remove o botão de voltar automático
      ),
      child: SafeArea( // Garante que o conteúdo não seja sobreposto por elementos da interface do sistema
        child: Padding(
          padding: const EdgeInsets.all(24), // Adiciona preenchimento em torno do conteúdo
          child: SizedBox( // Adiciona SizedBox para forçar o Column a ocupar toda a largura
            width: double.infinity, // Ocupa a largura máxima disponível
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start, // Mantém o conteúdo no topo
              crossAxisAlignment: CrossAxisAlignment.center, // Centraliza os filhos horizontalmente
              children: [
                const SizedBox(height: 50), // Margem adicionada no topo
                const Text(
                  "Bem-vindo ao Chat App PGDM", // Texto de boas-vindas
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center, // Centraliza o texto
                ),
                const SizedBox(height: 48), // Espaçamento vertical
                CupertinoButton.filled(
                  child: const Text("Entrar"), // Botão de login
                  onPressed: () {
                    Navigator.of(context).pushNamed("/login"); // Navega para a tela de login
                  },
                ),
                const SizedBox(height: 16), // Espaçamento vertical
                CupertinoButton(
                  child: const Text("Ainda não tem conta? Cadastrar"), // Botão de registro
                  onPressed: () {
                    Navigator.of(context).pushNamed("/register"); // Navega para a tela de registro
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
