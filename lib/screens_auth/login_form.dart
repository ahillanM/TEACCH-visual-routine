import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../theme.dart';

/// Username/password form. All auth logic lives in `AuthController`; this
/// widget only collects input and shows state.
class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _obscure = true;
  bool _remember = false;
  bool _initialised = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    _initialised = true;
    final remembered = AppScope.of(context).auth.rememberedUsername;
    if (remembered != null) {
      _username.text = remembered;
      _remember = true;
    }
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await AppScope.of(context).auth.signIn(
          username: _username.text,
          password: _password.text,
          remember: _remember,
        );
  }

  void _showForgotPassword() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forgot your password?'),
        content: const Text(
          'Please ask your trainer or the residential team. '
          'They can reset your password for you.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = AppScope.of(context).auth;
    final palette = context.palette;

    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        final busy = auth.isBusy;
        return AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Sign in', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpace.lg),
                if (auth.error != null) ...[
                  _ErrorBox(message: auth.error!),
                  const SizedBox(height: AppSpace.lg),
                ],
                TextFormField(
                  controller: _username,
                  enabled: !busy,
                  autofillHints: const [AutofillHints.username],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Username or email',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  onChanged: (_) => auth.clearError(),
                  onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter your username.'
                      : null,
                ),
                const SizedBox(height: AppSpace.md),
                TextFormField(
                  controller: _password,
                  focusNode: _passwordFocus,
                  enabled: !busy,
                  obscureText: _obscure,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      tooltip: _obscure ? 'Show password' : 'Hide password',
                      icon: Icon(_obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  onChanged: (_) => auth.clearError(),
                  onFieldSubmitted: (_) => _submit(),
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Please enter your password.'
                      : null,
                ),
                const SizedBox(height: AppSpace.sm),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      onTap: busy
                          ? null
                          : () => setState(() => _remember = !_remember),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: _remember,
                            onChanged: busy
                                ? null
                                : (v) => setState(() => _remember = v ?? false),
                          ),
                          const Text('Remember me'),
                          const SizedBox(width: AppSpace.sm),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _showForgotPassword,
                      child: const Text('Forgot password?'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.lg),
                SizedBox(
                  height: kLargeTouchTarget,
                  child: FilledButton(
                    onPressed: busy ? null : _submit,
                    child: busy
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: palette.onBrand),
                              ),
                              const SizedBox(width: AppSpace.md),
                              const Text('Signing in…'),
                            ],
                          )
                        : const Text('Sign in'),
                  ),
                ),
                const SizedBox(height: AppSpace.lg),
                const _DemoAccountsHint(),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          color: palette.danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: palette.danger.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: palette.danger),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Text(message, style: TextStyle(color: palette.danger)),
            ),
          ],
        ),
      ),
    );
  }
}

/// DEMO ONLY: lists the mock accounts so testers can sign in.
class _DemoAccountsHint extends StatelessWidget {
  const _DemoAccountsHint();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      shape: const Border(),
      title: Text('Demo accounts',
          style: TextStyle(color: palette.textSecondary, fontSize: 14)),
      children: [
        Text(
          'Staff: staff · Admin: admin\n'
          'Participants: lena, jonas, mia, elias\n'
          'Password for all: demo',
          style: TextStyle(color: palette.textSecondary, height: 1.5),
        ),
      ],
    );
  }
}
