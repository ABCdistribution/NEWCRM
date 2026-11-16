import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/erreur_api.dart';
import '../../core/auth/session.dart';
import '../../core/theme/theme.dart';

/// Couleurs de la page de connexion du web (`crm-web`, espace Direction) : fond blanc, champs gris clair, bouton
/// presque noir, violet au focus.
abstract final class _CouleursLogin {
  static const violet = Color(0xFF7656B8);
  static const champ = Color(0xFFF5F5F5); // neutral-100
  static const texte = Color(0xFF171717); // neutral-900
  static const etiquette = Color(0xFF262626); // neutral-800
  static const discret = Color(0xFF737373); // neutral-500
  static const erreurFond = Color(0xFFFEF2F2); // red-50
  static const erreurCadre = Color(0xFFFECACA); // red-200
  static const erreurTexte = Color(0xFFB91C1C); // red-700
}

/// Écran de connexion : identifiant et mot de passe de l'Active Directory, vérifiés par l'API.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _identifiant = TextEditingController();
  final _motDePasse = TextEditingController();
  bool _enCours = false;
  bool _afficher = false;
  String? _erreur;

  @override
  void dispose() {
    _identifiant.dispose();
    _motDePasse.dispose();
    super.dispose();
  }

  Future<void> _connecter() async {
    if (_enCours) return;
    if (_identifiant.text.trim().isEmpty || _motDePasse.text.isEmpty) {
      setState(
        () => _erreur = 'Saisissez votre identifiant et votre mot de passe.',
      );
      return;
    }
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    try {
      await ref
          .read(sessionProvider.notifier)
          .connecter(_identifiant.text, _motDePasse.text);
    } on ErreurApi catch (e) {
      if (mounted) setState(() => _erreur = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _erreur = const ErreurApi(TypeErreurApi.inattendue).message,
        );
      }
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  InputDecoration _decoration(String indice, {Widget? suffixe}) {
    OutlineInputBorder cadre(Color couleur) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: couleur),
    );
    return InputDecoration(
      hintText: indice,
      hintStyle: AppText.t(16, c: _CouleursLogin.discret),
      filled: true,
      fillColor: _CouleursLogin.champ,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      suffixIcon: suffixe,
      border: cadre(Colors.transparent),
      enabledBorder: cadre(Colors.transparent),
      disabledBorder: cadre(Colors.transparent),
      focusedBorder: cadre(_CouleursLogin.violet),
    );
  }

  Widget _etiquette(String texte) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      texte,
      style: AppText.t(14, w: FontWeight.w600, c: _CouleursLogin.etiquette),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, contraintes) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: contraintes.maxHeight - 56,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 380),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.asset(
                                'assets/images/logo.png',
                                width: 96,
                                height: 96,
                                fit: BoxFit.contain,
                                semanticLabel: 'ABC Group',
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'Bienvenue',
                            textAlign: TextAlign.center,
                            style: AppText.t(
                              30,
                              w: FontWeight.w800,
                              c: _CouleursLogin.texte,
                            ),
                          ),
                          const SizedBox(height: 32),
                          _etiquette('Identifiant'),
                          TextFormField(
                            controller: _identifiant,
                            enabled: !_enCours,
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            enableSuggestions: false,
                            autofillHints: const <String>[],
                            textCapitalization: TextCapitalization.none,
                            style: AppText.t(16, c: _CouleursLogin.texte),
                            decoration: _decoration('prénom.nom'),
                          ),
                          const SizedBox(height: 16),
                          _etiquette('Mot de passe'),
                          TextFormField(
                            controller: _motDePasse,
                            enabled: !_enCours,
                            obscureText: !_afficher,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _connecter(),
                            autocorrect: false,
                            enableSuggestions: false,
                            autofillHints: const <String>[],
                            style: AppText.t(16, c: _CouleursLogin.texte),
                            decoration: _decoration(
                              '••••••••',
                              suffixe: IconButton(
                                tooltip: _afficher
                                    ? 'Masquer le mot de passe'
                                    : 'Afficher le mot de passe',
                                onPressed: () =>
                                    setState(() => _afficher = !_afficher),
                                icon: Icon(
                                  _afficher
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 18,
                                  color: _CouleursLogin.discret,
                                ),
                              ),
                            ),
                          ),
                          if (_erreur != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: _CouleursLogin.erreurFond,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _CouleursLogin.erreurCadre,
                                ),
                              ),
                              child: Text(
                                _erreur!,
                                style: AppText.t(
                                  14,
                                  c: _CouleursLogin.erreurTexte,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 48,
                            child: FilledButton(
                              onPressed: _enCours ? null : _connecter,
                              style: FilledButton.styleFrom(
                                backgroundColor: _CouleursLogin.texte,
                                disabledBackgroundColor: _CouleursLogin.texte
                                    .withValues(alpha: 0.6),
                                foregroundColor: Colors.white,
                                disabledForegroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                textStyle: AppText.t(
                                  16,
                                  w: FontWeight.w500,
                                  c: Colors.white,
                                ),
                              ),
                              child: Text(
                                _enCours ? 'Connexion…' : 'Se connecter',
                              ),
                            ),
                          ),
                          // Profils de démonstration : builds de développement seulement.
                          if (kDebugMode) ...[
                            const SizedBox(height: 20),
                            Center(
                              child: TextButton(
                                onPressed: () => ref
                                    .read(modeDemoProvider.notifier)
                                    .entrer(),
                                child: Text(
                                  'Profils de démonstration',
                                  style: AppText.t(
                                    13,
                                    c: _CouleursLogin.discret,
                                  ),
                                ),
                              ),
                            ),
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
    );
  }
}
