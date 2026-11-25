import 'package:flutter/material.dart';

import '../logic/classes.dart';
import '../theme/theme.dart';

/// Variantes de pastille (`.p-gris`, `.p-bleu`…).
enum VariantePastille { gris, violet, jaune, bleu, vert, rouge, client, rose }

/// Petite étiquette arrondie (`.pastille`) : statut, classe, état.
///
/// ```dart
/// const Pastille('Livrée', variante: VariantePastille.vert)
/// ```
class Pastille extends StatelessWidget {
  const Pastille(
    this.label, {
    super.key,
    this.variante = VariantePastille.gris,
    this.fond,
    this.texte,
    this.petite = false,
  });

  final String label;
  final VariantePastille variante;

  /// Couleurs libres (ex. pastille de promo rose, compteurs écarts) : remplacent la variante.
  final Color? fond;
  final Color? texte;

  /// Version réduite (`padding: 1px 6px; font-size: 10.5px`), ex. étiquette « EDI ».
  final bool petite;

  @override
  Widget build(BuildContext context) {
    final u = context.univers;
    final (bg, fg) = switch (variante) {
      VariantePastille.gris => (AppColors.pGrisFond, AppColors.pGrisTexte),
      VariantePastille.violet => (AppColors.violetTeinte, u.violet),
      VariantePastille.jaune => (AppColors.pJauneFond, AppColors.pJauneTexte),
      VariantePastille.bleu => (AppColors.pBleuFond, AppColors.pBleuTexte),
      VariantePastille.vert => (AppColors.pVertFond, AppColors.pVertTexte),
      VariantePastille.rouge => (AppColors.pRougeFond, AppColors.pRougeTexte),
      VariantePastille.client => (
        AppColors.pClientFond,
        AppColors.pClientTexte,
      ),
      VariantePastille.rose => (AppColors.pRoseFond, AppColors.pRoseTexte),
    };
    return Container(
      padding: petite
          ? const EdgeInsets.symmetric(horizontal: 6, vertical: 1)
          : const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: fond ?? bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        softWrap: false,
        style: AppText.t(
          petite ? 10.5 : 11.5,
          w: FontWeight.w800,
          c: texte ?? fg,
        ),
      ),
    );
  }
}

/// Pastille de classe d'un client (« A » à « G »). Rien n'est affiché si la classe est inconnue ou invalide ;
/// `avecMot` ajoute « Classe » devant la lettre.
class PastilleClasse extends StatelessWidget {
  const PastilleClasse(
    this.classe, {
    super.key,
    this.avecMot = false,
    this.petite = true,
  });

  final String? classe;
  final bool avecMot;
  final bool petite;

  @override
  Widget build(BuildContext context) {
    final c = classeValide(classe);
    if (c.isEmpty) return const SizedBox.shrink();
    return Pastille(
      avecMot ? 'Classe $c' : c,
      variante: VariantePastille.client,
      petite: petite,
    );
  }
}

/// Nom d'un client suivi de sa pastille de classe (aucune pastille si la classe est inconnue).
class NomMagasin extends StatelessWidget {
  const NomMagasin(this.nom, {super.key, this.classe, this.style});

  final String nom;
  final String? classe;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final texte = Text(nom, style: style ?? AppText.titreCarte);
    if (classeValide(classe).isEmpty) return texte;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [texte, PastilleClasse(classe)],
    );
  }
}

/// Carte blanche (`.carte`) : rayon 20, halo coloré de l'univers, marge basse de 10.
///
/// `onTap` la rend cliquable ; `prochain` ajoute le contour d'accent (carte « Prochain » de la tournée).
class AppCarte extends StatelessWidget {
  const AppCarte({
    super.key,
    required this.child,
    this.onTap,
    this.prochain = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    this.margeBas = 10,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool prochain;
  final EdgeInsetsGeometry padding;
  final double margeBas;

  @override
  Widget build(BuildContext context) {
    final u = context.univers;
    final carte = Container(
      margin: EdgeInsets.only(bottom: margeBas),
      padding: prochain ? const EdgeInsets.all(14) : padding,
      decoration: BoxDecoration(
        color: AppColors.carte,
        borderRadius: BorderRadius.circular(20),
        border: prochain ? Border.all(color: u.acc, width: 1.6) : null,
        boxShadow: u.ombreCarte,
      ),
      child: child,
    );
    if (onTap == null) return carte;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: carte,
    );
  }
}

/// Ligne horizontale de la maquette (`.ligne` : flex, gap 10, alignée en haut par défaut).
class AppLigne extends StatelessWidget {
  const AppLigne({
    super.key,
    required this.children,
    this.alignement = CrossAxisAlignment.start,
    this.gap = 10,
  });

  final List<Widget> children;
  final CrossAxisAlignment alignement;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) items.add(SizedBox(width: gap));
      items.add(children[i]);
    }
    return Row(crossAxisAlignment: alignement, children: items);
  }
}

/// État d'un rond de tournée.
enum EtatRond { normal, prochain, fait }

/// Rond d'icône de 36 px (`.rond`) ; `fait` = vert, `prochain` = teinte d'accent.
class Rond extends StatelessWidget {
  const Rond({
    super.key,
    required this.child,
    this.etat = EtatRond.normal,
    this.taille = 36,
    this.rayon,
    this.fond,
  });

  final Widget child;
  final EtatRond etat;
  final double taille;

  /// Rayon des coins ; nul = cercle.
  final double? rayon;
  final Color? fond;

  @override
  Widget build(BuildContext context) {
    final u = context.univers;
    final (bg, fg) = switch (etat) {
      EtatRond.normal => (AppColors.grisRond, AppColors.muted),
      EtatRond.prochain => (AppColors.violetTeinte, u.violet),
      EtatRond.fait => (AppColors.rondFait, AppColors.ok),
    };
    return Container(
      width: taille,
      height: taille,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fond ?? bg,
        shape: rayon == null ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: rayon == null ? null : BorderRadius.circular(rayon!),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: fg),
        child: child,
      ),
    );
  }
}

/// Lien texte d'accent (`.lien`), souligné en option.
class LienTexte extends StatelessWidget {
  const LienTexte(
    this.label, {
    super.key,
    required this.onTap,
    this.souligne = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool souligne;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Text(
        label,
        style: AppText.t(
          13.5,
          w: FontWeight.w700,
          c: context.univers.acc,
          deco: souligne ? TextDecoration.underline : null,
        ),
      ),
    );
  }
}

/// Texte souligné avec épaisseur et décalage réglables (`text-decoration-thickness`, `text-underline-offset`) :
/// `TextDecoration.underline` ne permet ni l'un ni l'autre. Le soulignement est un filet tracé sous la ligne, à
/// `decalage` dp sous la ligne de base (la descente de la police Inter, 494/2048 em, est déjà sous elle).
///
/// Pour un texte d'une seule ligne ; pour un souligné par défaut dans un texte courant, `TextDecoration.underline`.
class TexteSouligne extends StatelessWidget {
  const TexteSouligne(
    this.texte, {
    super.key,
    required this.style,
    this.epaisseur = 1.5,
    this.decalage = 4,
  });

  final String texte;
  final TextStyle style;
  final double epaisseur;
  final double decalage;

  @override
  Widget build(BuildContext context) {
    final descente = (style.fontSize ?? 16) * 494 / 2048;
    final ecart = decalage > descente ? decalage - descente : 0.0;
    return Container(
      padding: EdgeInsets.only(bottom: ecart),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: style.color ?? AppColors.texte,
            width: epaisseur,
          ),
        ),
      ),
      child: Text(texte, style: style),
    );
  }
}

/// Titre de section avec lien optionnel à droite (`.titre-ligne`).
class TitreLigne extends StatelessWidget {
  const TitreLigne(
    this.titre, {
    super.key,
    this.taille = 19,
    this.lien,
    this.onLien,
    this.droite,
    this.margeHaut = 0,
  });

  final String titre;
  final double taille;

  /// Texte du lien (« Voir tous ») et son action.
  final String? lien;
  final VoidCallback? onLien;

  /// Widget libre à droite (compteur, bouton filtre…), à la place du lien.
  final Widget? droite;
  final double margeHaut;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: margeHaut, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(titre, style: AppText.t(taille, w: FontWeight.w800)),
          ),
          if (droite != null)
            droite!
          else if (lien != null && onLien != null)
            LienTexte(lien!, onTap: onLien!),
        ],
      ),
    );
  }
}

/// Bloc « rien à afficher » (`.vide`) : texte gris centré sur carte blanche.
class Vide extends StatelessWidget {
  const Vide(this.texte, {super.key});
  final String texte;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.ligne),
      ),
      child: Text(
        texte,
        textAlign: TextAlign.center,
        style: AppText.t(16, c: AppColors.muted),
      ),
    );
  }
}

/// Une case de la rangée de chiffres clés (`.kpi`).
class KpiItem {
  const KpiItem(
    this.libelle,
    this.valeur, {
    this.sous,
    this.evo,
    this.couleurValeur,
  });
  final String libelle;
  final String valeur;

  /// Petite ligne sous la valeur (« 26 oct. », « obj. 2 »).
  final String? sous;

  /// Évolution en orange (« −14 % »).
  final String? evo;
  final Color? couleurValeur;
}

/// Rangée de chiffres clés sur cartes blanches (`.kpi`).
class KpiRangee extends StatelessWidget {
  const KpiRangee(this.items, {super.key});
  final List<KpiItem> items;

  @override
  Widget build(BuildContext context) {
    final u = context.univers;
    final cases = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final k = items[i];
      if (i > 0) cases.add(const SizedBox(width: 8));
      cases.add(
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: u.ombreCarte,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(k.libelle, style: AppText.t(11, c: AppColors.muted)),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    k.valeur,
                    style: AppText.t(
                      18,
                      w: FontWeight.w700,
                      c: k.couleurValeur,
                    ),
                  ),
                ),
                if (k.evo != null && k.evo!.isNotEmpty)
                  Text(
                    k.evo!,
                    style: AppText.t(11, w: FontWeight.w700, c: AppColors.warn),
                  ),
                if (k.sous != null)
                  Text(k.sous!, style: AppText.t(11, c: AppColors.muted)),
              ],
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: cases,
        ),
      ),
    );
  }
}

/// Bandeau d'information blanc (`.bandeau`) : titre avec icône emoji, texte gris, contenu libre.
class BandeauInfo extends StatelessWidget {
  const BandeauInfo({
    super.key,
    required this.titre,
    this.icone,
    this.detail,
    this.child,
  });

  final String titre;

  /// Emoji devant le titre.
  final String? icone;
  final String? detail;

  /// Contenu libre sous le texte (bouton, liste).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final u = context.univers;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: u.ombreCarte,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icone != null) ...[
                Text(icone!, style: AppText.t(14.5)),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(titre, style: AppText.t(14.5, w: FontWeight.w700)),
              ),
            ],
          ),
          if (detail != null)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(detail!, style: AppText.t(12.5, c: AppColors.muted)),
            ),
          ?child,
        ],
      ),
    );
  }
}

/// « 📤 En attente d'envoi » (`.en-attente`) : élément créé sur le téléphone, pas encore envoyé.
class EnAttente extends StatelessWidget {
  const EnAttente({super.key, this.texte = "📤 En attente d'envoi"});
  final String texte;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(
      texte,
      style: AppText.t(12, w: FontWeight.w700, c: AppColors.warn),
    ),
  );
}
