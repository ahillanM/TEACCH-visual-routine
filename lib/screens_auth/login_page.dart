import 'package:flutter/material.dart';

import 'auth_layout.dart';
import 'login_form.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuthLayout(child: LoginForm());
  }
}
