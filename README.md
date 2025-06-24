# Chat App

## Descrição

Aplicativo de mensagens moderno desenvolvido com Flutter e Firebase, projetado para comunicação em tempo real, notificações push e envio de imagens. 

Aplicativo desenvolvido para a matéria de Desenvolvimento para Dispositivos Móveis.

---

## Índice

* [Tecnologias](#tecnologias)
* [Funcionalidades](#funcionalidades)
* [Pré-requisitos](#pré-requisitos)
* [Instalação](#instalação)
* [Uso](#uso)
* [Licença](#licença)

---

## Tecnologias

* Flutter (Dart)
* Firebase: Auth, Firestore, Storage, Messaging

---

## Funcionalidades

* Autenticação de usuários via Firebase Auth
* Envio e recebimento de mensagens em tempo real com Firestore
* Upload e visualização de imagens usando Firebase Storage
* Resposta a mensagens (reply)
* Edição de perfil do usuário

---

## Pré-requisitos

* Flutter 3.19 ou superior
* Projeto Firebase configurado (Auth, Firestore, Storage, Messaging)
* Ambiente configurado para Android, iOS e/ou Web

---

## Instalação

1. Clone o repositório:

   ```bash
   git clone <URL_DO_REPOSITÓRIO>
   ```
2. Acesse o diretório do projeto:

   ```bash
   cd chat_app
   ```
3. Instale as dependências:

   ```bash
   flutter pub get
   ```
4. Gere o arquivo `firebase_options.dart` utilizando FlutterFire CLI:

   ```bash
   flutterfire configure
   ```
5. Execute o aplicativo:

   ```bash
   flutter run
   ```

---

## Uso

Após configurar o ambiente, o app permite:

* Criar conta e efetuar login
* Enviar textos e imagens em tempo real
* Responder a mensagens específicas
* Editar informação de perfil

---

## Observação
Este projeto continua em fase de desenvolvimento e pode sofrer alterações. Funcionalidades, estrutura e comportamento estão sujeitos a mudança até a finalização.

---

## Licença

Este projeto está licenciado sob a [MIT License](./LICENSE).