import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session.dart';
import '../logic/dates.dart';
import '../models/models.dart';
import '../nav/app_routes.dart';
import '../state/state.dart';
import '../sync/photos_provider.dart';
import '../theme/theme.dart';
import 'app_icons.dart';
import 'boutons.dart';

/// Entête de page (`.entete`) : titre, sous-titre, contenu libre. Défile avec la page, sans fond propre
/// (le dégradé de l'univers passe derrière).
///
/// ```dart
/// AppEntete(titre: 'Clients', sous: '12 clients', extra: BarreRecherche(...))
/// ```
class AppEntete extends StatelessWidget {
  const AppEntete({
    super.key,
    required String this.titre,
    this.sous,
    this.extra,
    this.trailing,
    this.tailleTitre = 23,
  }) : _libre = null;

  /// Entête entièrement libre (fiche avec bouton retour, badge, actions…), avec le même padding.
  const AppEntete.libre({super.key, required Widget child})
    : titre = null,
      _libre = child,
      sous = null,
      extra = null,
      trailing = null,
      tailleTitre = 23;

  final String? titre;
  final Widget? _libre;
  final String? sous;

  /// Contenu sous le titre : recherche, tuiles, jours…
  final Widget? extra;

  /// Widget à droite du titre (bouton scan, flèches de semaine).
  final Widget? trailing;
  final double tailleTitre;

  @override
  Widget build(BuildContext context) {
    final u = context.univers;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child:
          _libre ??
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titre!,
                          style: AppText.t(
                            tailleTitre,
                            w: FontWeight.w800,
                            c: u.encre,
                          ),
                        ),
                        if (sous != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              sous!,
                              style: AppText.t(12.5, c: u.encre2),
                            ),
                          ),
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
              ?extra,
            ],
          ),
    );
  }
}

/// Barre supérieure d'un écran empilé (`.topbar`) : retour, titre, sous-titre, élément à droite.
class TopbarEcran extends StatelessWidget {
  const TopbarEcran({
    super.key,
    required this.titre,
    this.sous,
    this.droite,
    this.onRetour,
    this.tailleTitre = 18,
  });

  final String titre;
  final String? sous;
  final Widget? droite;
  final VoidCallback? onRetour;
  final double tailleTitre;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          BoutonRetour(onTap: onRetour),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titre, style: AppText.t(tailleTitre, w: FontWeight.w800)),
                if (sous != null)
                  Text(sous!, style: AppText.t(12, c: AppColors.muted)),
              ],
            ),
          ),
          if (droite != null) ...[const SizedBox(width: 12), droite!],
        ],
      ),
    );
  }
}

/// Repère du niveau d'encadrement à côté du rôle (`.badge-role`) : ★ chef de secteur, ★★ directeur.
class BadgeRole extends StatelessWidget {
  const BadgeRole(this.role, {super.key});
  final Role role;

  @override
  Widget build(BuildContext context) {
    if (role == Role.promoteur) return const SizedBox.shrink();
    final dir = role == Role.dir;
    return Container(
      height: 17,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: dir ? null : const Color(0xFFFBBF24),
        gradient: dir
            ? const DegradeCss(colors: [Color(0xFFFDE68A), Color(0xFFF59E0B)])
            : null,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          dir ? '★★' : '★',
          style: AppText.t(
            10.5,
            w: FontWeight.w800,
            c: const Color(0xFF78350F),
            espacement: 1,
          ),
        ),
      ),
    );
  }
}

/// Avatar rond d'initiales (`.avatar`, 42 px) : blanc avec halo. `fond`/`texte` pour les avatars d'équipe teintés :
/// ils gardent le halo (`.u-pilot .avatar` ne reçoit qu'un `background` en ligne).
class Avatar extends StatelessWidget {
  const Avatar(
    this.initiales, {
    super.key,
    this.taille = 42,
    this.fond,
    this.texte,
    this.onTap,
    this.photo,
  });

  /// Photo de profil (JPEG ou PNG) ; sans elle, les initiales.
  final Uint8List? photo;

  final String initiales;
  final double taille;
  final Color? fond;
  final Color? texte;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final u = context.univers;
    final rond = Container(
      width: taille,
      height: taille,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fond ?? Colors.white,
        shape: BoxShape.circle,
        boxShadow: u.ombreRond,
      ),
      clipBehavior: Clip.antiAlias,
      child: photo == null
          ? Text(
              initiales,
              style: AppText.t(14, w: FontWeight.w800, c: texte ?? u.acc),
            )
          : Image.memory(
              photo!,
              width: taille,
              height: taille,
              fit: BoxFit.cover,
              cacheWidth: (taille * 3).round(),
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => Text(
                initiales,
                style: AppText.t(14, w: FontWeight.w800, c: texte ?? u.acc),
              ),
            ),
    );
    if (onTap == null) return rond;
    return GestureDetector(onTap: onTap, child: rond);
  }
}

/// Avatar d'un utilisateur du CRM : sa photo de profil si elle est téléchargée, sinon ses initiales.
class AvatarUtilisateur extends ConsumerWidget {
  const AvatarUtilisateur(
    this.userId,
    this.initiales, {
    super.key,
    this.taille = 42,
    this.fond,
    this.texte,
    this.onTap,
  });

  final String? userId;
  final String initiales;
  final double taille;
  final Color? fond;
  final Color? texte;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = userId == null
        ? null
        : ref.watch(photosProvider.select((m) => m[userId]));
    return Avatar(
      initiales,
      taille: taille,
      fond: fond,
      texte: texte,
      onTap: onTap,
      photo: photo,
    );
  }
}

/// Cloche d'alertes (`.cloche`, 42 px) avec pastille du nombre d'alertes.
class Cloche extends StatelessWidget {
  const Cloche({super.key, required this.nombre, required this.onTap});

  final int nombre;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final u = context.univers;
    return Semantics(
      button: true,
      label: 'Alertes',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Stack(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: u.ombreRond,
                ),
                child: AppIcon(AppIcons.cloche, color: u.acc),
              ),
              if (nombre > 0)
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: AppColors.compteur,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '$nombre',
                      style: AppText.t(
                        10,
                        w: FontWeight.w800,
                        c: const Color(0xFF111827),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bandeau « Bonjour {prénom} » de l'accueil (`.bonjour`) : avatar, rôle avec ★, cloche.
///
/// Déjà câblé : un appui sur l'avatar ouvre « Changer de profil (démo) », un appui sur la cloche ouvre
/// les alertes (`AppRoutes.alertes`), le compteur vient de `alertesProvider`.
class BandeauBonjour extends ConsumerWidget {
  const BandeauBonjour({super.key, this.sous});

  /// Texte sous « Bonjour… » ; par défaut « {rôle} · mer. 4 nov. ».
  final String? sous;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profil = ref.watch(profilActifProvider);
    // Connecté : prénom et initiales de l'utilisateur réel (le reste dépend encore des données de démo).
    final reel = ref.watch(sessionProvider);
    final nbAlertes = ref.watch(alertesProvider.select((l) => l.length));
    final u = context.univers;
    final texte = sous ?? '${profil.libelle} · ${DemoTemps.dateLibelle}';
    final i = texte.indexOf(profil.libelle);
    final style = AppText.t(12.5, w: FontWeight.w600, c: u.encre2);
    final spans = i < 0
        ? [TextSpan(text: texte)]
        : <InlineSpan>[
            TextSpan(text: texte.substring(0, i + profil.libelle.length)),
            if (profil.role != Role.promoteur)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: BadgeRole(profil.role),
                ),
              ),
            TextSpan(text: texte.substring(i + profil.libelle.length)),
          ];
    return Row(
      children: [
        AvatarUtilisateur(
          reel?.id,
          reel?.initiales ?? profil.initiales,
          onTap: () => AppRoutes.changerProfil(context),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bonjour ${reel?.prenom ?? profil.prenom}',
                style: AppText.t(19, w: FontWeight.w700, c: u.encre),
              ),
              Text.rich(TextSpan(children: spans), style: style),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Cloche(nombre: nbAlertes, onTap: () => AppRoutes.alertes(context)),
      ],
    );
  }
}

/// Une tuile de chiffre clé de l'entête (`.tuile`) : libellé et valeur sur fond blanc translucide.
class Tuile extends StatelessWidget {
  const Tuile({
    super.key,
    required this.libelle,
    this.valeur,
    this.complement,
    this.flex = 1,
    this.tailleValeur = 22,
    this.tailleComplement = 14,
    this.poidsComplement = FontWeight.w800,
    this.opaciteComplement = 0.75,
    this.centre = false,
    this.actif = false,
    this.onTap,
    this.child,
    this.nowrap = false,
  });

  final String libelle;

  /// Valeur principale (« 2/5 »).
  final String? valeur;

  /// Suite de la valeur, plus petite et estompée (« / 4 900 € »).
  final String? complement;

  /// Poids dans la rangée (la tuile « CA / objectif » vaut 2).
  final int flex;
  final double tailleValeur;

  /// Complément de la valeur : 14 px à 75 % (« 5 / 9 »), ou 13 px, graisse 600, 70 % pour « / 4 900 € »
  /// (`<span style="font-size:13px;opacity:.7;font-weight:600">`).
  final double tailleComplement;
  final FontWeight poidsComplement;
  final double opaciteComplement;

  /// Tuile centrée et cliquable (`.tuile.c`), ex. filtres du pipeline ; `actif` = tuile sélectionnée.
  final bool centre;
  final bool actif;
  final VoidCallback? onTap;

  /// Contenu libre à la place de la valeur (valeur + barre de progression).
  final Widget? child;

  /// La valeur ne passe jamais à la ligne (`white-space:nowrap` de la tuile « CA / objectif »).
  final bool nowrap;

  @override
  Widget build(BuildContext context) {
    final u = context.univers;
    final couleurValeur = actif ? u.acc : u.encre;
    final couleurLibelle = actif ? u.acc : u.encre2;
    final contenu = Column(
      crossAxisAlignment: centre
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (centre && valeur != null)
          Text(
            valeur!,
            style: AppText.t(
              tailleValeur,
              w: FontWeight.w800,
              c: couleurValeur,
            ),
          )
        else
          const SizedBox.shrink(),
        Text(libelle, style: AppText.t(11.5, c: couleurLibelle)),
        if (!centre && valeur != null)
          Text.rich(
            softWrap: !nowrap,
            TextSpan(
              children: [
                TextSpan(text: valeur),
                if (complement != null)
                  TextSpan(
                    text: ' $complement',
                    style: AppText.t(
                      tailleComplement,
                      w: poidsComplement,
                      c: couleurValeur.withValues(alpha: opaciteComplement),
                    ),
                  ),
              ],
            ),
            style: AppText.t(
              tailleValeur,
              w: FontWeight.w800,
              c: couleurValeur,
            ),
          ),
        ?child,
      ],
    );
    final boite = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: actif ? Colors.white : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        boxShadow: u.ombreDouce,
      ),
      child: contenu,
    );
    if (onTap == null) return boite;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: boite,
    );
  }
}

/// Rangée de tuiles d'entête (`.tuiles`, gap 8, marge haute 14). Les tuiles se partagent la largeur selon leur `flex`.
class TuilesRangee extends StatelessWidget {
  const TuilesRangee(this.tuiles, {super.key});
  final List<Tuile> tuiles;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < tuiles.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(flex: tuiles[i].flex, child: tuiles[i]),
            ],
          ],
        ),
      ),
    );
  }
}
