import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/state/state.dart';
import '../../core/theme/theme.dart';

/// Écran de lancement : choix du profil de démonstration (la maquette le fait avec les boutons de gauche).
///
/// Trois cartes : Promoteur (univers bleu), Chef de secteur et Directeur régional (univers violet).
class ChoixProfilScreen extends ConsumerWidget {
  const ChoixProfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF14132A),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: const Alignment(-0.34, -0.94),
            end: const Alignment(0.34, 0.94),
            colors: [
              const Color(0xFF170D30),
              const Color(0xFF3F2A85),
              Color.lerp(
                const Color(0xFF3F2A85),
                const Color(0xFF6A4CC4),
                0.69,
              )!,
            ],
            stops: const [0, 0.55, 1],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBBF24),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'DÉMO',
                        style: AppText.t(
                          12,
                          w: FontWeight.w800,
                          c: const Color(0xFF78350F),
                          espacement: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nouveau CRM ABC',
                      style: AppText.t(28, w: FontWeight.w800, c: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Démonstration de l’application mobile · données fictives',
                      style: AppText.t(14, c: const Color(0xFFD8D6EE)),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Choisissez un profil de démonstration',
                      style: AppText.t(16, w: FontWeight.w700, c: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    const _Groupe(
                      libelle: 'Partie promoteur',
                      couleur: Color(0xFF9ED2FE),
                      point: Color(0xFF65B8FD),
                    ),
                    const _CarteProfil(
                      role: Role.promoteur,
                      couleurs: [Color(0xFF65B8FD), Color(0xFF1F7AEA)],
                    ),
                    const SizedBox(height: 12),
                    const _Groupe(
                      libelle: 'Partie direction',
                      couleur: Color(0xFFCDBBFD),
                      point: Color(0xFFB396FB),
                    ),
                    const _CarteProfil(
                      role: Role.cs,
                      couleurs: [Color(0xFFB396FB), Color(0xFF7A56E6)],
                    ),
                    const SizedBox(height: 10),
                    const _CarteProfil(
                      role: Role.dir,
                      couleurs: [Color(0xFFB396FB), Color(0xFF7A56E6)],
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

class _Groupe extends StatelessWidget {
  const _Groupe({
    required this.libelle,
    required this.couleur,
    required this.point,
  });

  final String libelle;
  final Color couleur;
  final Color point;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: point, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            libelle.toUpperCase(),
            style: AppText.t(
              12,
              w: FontWeight.w700,
              c: couleur,
              espacement: 0.7,
            ),
          ),
        ],
      ),
    );
  }
}

class _CarteProfil extends ConsumerWidget {
  const _CarteProfil({required this.role, required this.couleurs});

  final Role role;
  final List<Color> couleurs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = role.profil;
    return Semantics(
      button: true,
      label: p.libelle,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => ref.read(roleProvider.notifier).choisir(role),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: couleurs,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: couleurs.first),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  p.initiales,
                  style: AppText.t(15, w: FontWeight.w800, c: couleurs.last),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.libelle,
                      style: AppText.t(17, w: FontWeight.w800, c: Colors.white),
                    ),
                    Text(
                      p.nom,
                      style: AppText.t(
                        13,
                        c: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Text('›', style: AppText.t(24, c: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}
