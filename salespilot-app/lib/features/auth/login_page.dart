import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';

/// Connexion par le compte Active Directory. Aussi utilisée pour se reconnecter après expiration du jeton
/// ([relogin]) : les saisies en attente sont conservées.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key, this.relogin = false});

  final bool relogin;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  var _busy = false;
  var _hide = true;
  String? _error;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider.notifier).login(_user.text, _pass.text);
      if (!mounted) return;
      // Un envoi en attente repart dès la reconnexion.
      ref.read(syncControllerProvider.notifier).run();
      if (widget.relogin) context.go('/');
    } on Object catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = SpacePalette.sales;
    return Scaffold(
      backgroundColor: palette.nav,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset('assets/images/logo-salespilot.png', height: 72),
                    const SizedBox(height: 32),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(widget.relogin ? 'Reconnexion' : 'Connexion',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(
                              widget.relogin
                                  ? 'Votre session a expiré. Vos saisies sont conservées et seront envoyées après la reconnexion.'
                                  : 'Utilisez votre compte Windows (Active Directory).',
                              style: const TextStyle(color: StatusColors.muted),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _user,
                              autofillHints: const [AutofillHints.username],
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(labelText: 'Identifiant', prefixIcon: Icon(Icons.person_outline)),
                              validator: (v) => (v ?? '').trim().isEmpty ? 'Identifiant requis' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _pass,
                              obscureText: _hide,
                              autofillHints: const [AutofillHints.password],
                              onFieldSubmitted: (_) => _submit(),
                              decoration: InputDecoration(
                                labelText: 'Mot de passe',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  tooltip: _hide ? 'Afficher' : 'Masquer',
                                  icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                  onPressed: () => setState(() => _hide = !_hide),
                                ),
                              ),
                              validator: (v) => (v ?? '').isEmpty ? 'Mot de passe requis' : null,
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Text(_error!, style: const TextStyle(color: StatusColors.alert), semanticsLabel: 'Erreur : $_error'),
                            ],
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: _busy ? null : _submit,
                              child: _busy
                                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                  : const Text('Se connecter'),
                            ),
                            if (widget.relogin) ...[
                              const SizedBox(height: 8),
                              TextButton(onPressed: () => context.go('/'), child: const Text('Plus tard')),
                            ],
                          ],
                        ),
                      ),
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

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}
