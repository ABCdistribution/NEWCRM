import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'app_icons.dart';

/// Champ de saisie (`.champ`) : étiquette grise au-dessus, cadre arrondi, message d'erreur rouge.
///
/// ```dart
/// ChampTexte(label: 'Enseigne *', controller: c, erreur: 'Enseigne requise')
/// ```
class ChampTexte extends StatelessWidget {
  const ChampTexte({
    super.key,
    required this.label,
    this.controller,
    this.valeurInitiale,
    this.onChanged,
    this.hint,
    this.erreur,
    this.lignes = 1,
    this.clavier,
    this.margeBas = 12,
    this.activer = true,
    this.hauteur = 72,
    this.masque = false,
    this.actionClavier,
    this.onValider,
    this.indicesAuto,
  });

  final String label;
  final TextEditingController? controller;
  final String? valeurInitiale;
  final ValueChanged<String>? onChanged;
  final String? hint;

  /// Message d'erreur : met le cadre en rouge et l'affiche dessous.
  final String? erreur;

  /// Plus de 1 = zone de texte (`textarea`) : hauteur fixe `hauteur`, le texte défile au-delà.
  final int lignes;
  final TextInputType? clavier;
  final double margeBas;
  final bool activer;

  /// Saisie masquée (mot de passe).
  final bool masque;

  /// Touche d'action du clavier (suivant, terminé…) et rappel à la validation.
  final TextInputAction? actionClavier;
  final ValueChanged<String>? onValider;

  /// Indices de saisie automatique ; une liste vide désactive la saisie automatique et la proposition d'enregistrer le mot de passe.
  final Iterable<String>? indicesAuto;

  /// Hauteur d'une zone de texte (`.champ textarea{min-height:72px}`, jamais atteinte par ses deux lignes par défaut).
  final double hauteur;

  Widget _zone({required bool multiligne, required Widget champ}) =>
      multiligne ? SizedBox(height: hauteur, child: champ) : champ;

  @override
  Widget build(BuildContext context) {
    final u = context.univers;
    final multiligne = lignes > 1;
    final cadre = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: erreur != null ? AppColors.alert : AppColors.bordureChamp,
      ),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: margeBas),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(label, style: AppText.etiquetteChamp),
          ),
          _zone(
            multiligne: multiligne,
            champ: TextFormField(
              controller: controller,
              initialValue: controller == null ? valeurInitiale : null,
              onChanged: onChanged,
              enabled: activer,
              obscureText: masque,
              textInputAction: actionClavier,
              onFieldSubmitted: onValider,
              autofillHints: indicesAuto,
              autocorrect: !masque,
              enableSuggestions: !masque,
              keyboardType:
                  clavier ?? (multiligne ? TextInputType.multiline : null),
              expands: multiligne,
              minLines: multiligne ? null : 1,
              maxLines: multiligne ? null : 1,
              textAlignVertical: multiligne ? TextAlignVertical.top : null,
              style: AppText.champ,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppText.t(14, c: AppColors.muted),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: cadre,
                enabledBorder: cadre,
                disabledBorder: cadre,
                focusedBorder: cadre.copyWith(
                  borderSide: BorderSide(
                    color: erreur != null ? AppColors.alert : u.acc,
                  ),
                ),
              ),
            ),
          ),
          if (erreur != null)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(erreur!, style: AppText.t(11.5, c: AppColors.alert)),
            ),
        ],
      ),
    );
  }
}

/// Liste déroulante (`select` de la maquette) avec étiquette.
class ChampListe<T> extends StatelessWidget {
  const ChampListe({
    super.key,
    required this.label,
    required this.valeur,
    required this.options,
    required this.onChanged,
    this.margeBas = 12,
  });

  final String label;
  final T valeur;

  /// Valeur → texte affiché.
  final Map<T, String> options;
  final ValueChanged<T> onChanged;
  final double margeBas;

  @override
  Widget build(BuildContext context) {
    final cadre = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.bordureChamp),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: margeBas),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(label, style: AppText.etiquetteChamp),
          ),
          DropdownButtonFormField<T>(
            initialValue: options.containsKey(valeur) ? valeur : null,
            isExpanded: true,
            style: AppText.champ,
            // `iconSize` : sans lui le bouton réserve 24 dp pour une flèche de 16 et tronque les libellés trop tôt.
            iconSize: 16,
            icon: const AppIcon(
              AppIcons.chevronBas,
              size: 16,
              color: AppColors.texte,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: cadre,
              enabledBorder: cadre,
              focusedBorder: cadre,
            ),
            items: [
              for (final e in options.entries)
                DropdownMenuItem<T>(
                  value: e.key,
                  child: Text(
                    e.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}

/// Rond de bouton radio (`.radio`) : 20 px, point central bleu quand sélectionné.
class Radio20 extends StatelessWidget {
  const Radio20({super.key, required this.selectionne});
  final bool selectionne;

  @override
  Widget build(BuildContext context) {
    final bleu = context.univers.bleu;
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selectionne ? bleu : AppColors.bordureChamp,
          width: 2,
        ),
      ),
      child: selectionne
          ? Padding(
              padding: const EdgeInsets.all(3),
              child: DecoratedBox(
                decoration: BoxDecoration(shape: BoxShape.circle, color: bleu),
              ),
            )
          : null,
    );
  }
}

/// Ligne d'option à choix unique (`.opt`) des feuilles de filtres : libellé et radio.
class OptionRadio extends StatelessWidget {
  const OptionRadio({
    super.key,
    required this.label,
    required this.selectionne,
    required this.onTap,
    this.detail,
  });

  final String label;
  final bool selectionne;
  final VoidCallback onTap;

  /// Complément gris après le libellé (« (12) »).
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.ligne)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: label,
                  children: [
                    if (detail != null)
                      TextSpan(
                        text: ' $detail',
                        style: AppText.t(12.5, c: AppColors.muted),
                      ),
                  ],
                ),
                style: AppText.t(15),
              ),
            ),
            const SizedBox(width: 12),
            Radio20(selectionne: selectionne),
          ],
        ),
      ),
    );
  }
}

/// Interrupteur (`.sw`, 46 × 26) : fond bleu quand actif.
class Interrupteur extends StatelessWidget {
  const Interrupteur({
    super.key,
    required this.valeur,
    required this.onChanged,
  });

  final bool valeur;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final bleu = context.univers.bleu;
    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!valeur),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 46,
        height: 26,
        padding: const EdgeInsets.all(3),
        alignment: valeur ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: valeur ? bleu : const Color(0xFFCBD2E0),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// Ligne « libellé + interrupteur » (`.qrow`).
class LigneSwitch extends StatelessWidget {
  const LigneSwitch({
    super.key,
    required this.label,
    required this.valeur,
    required this.onChanged,
  });

  final String label;
  final bool valeur;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: AppText.t(14))),
          const SizedBox(width: 12),
          Interrupteur(valeur: valeur, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// Case à cocher carrée (`.case`, 22 px).
class CaseCoche extends StatelessWidget {
  const CaseCoche({super.key, required this.cochee, this.onChanged});

  final bool cochee;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final bleu = context.univers.bleu;
    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!cochee),
      child: Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cochee ? bleu : null,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: cochee ? bleu : AppColors.bordureChamp,
            width: 2,
          ),
        ),
        child: cochee ? Text('✓', style: AppText.t(14, c: Colors.white)) : null,
      ),
    );
  }
}

/// Compteur « − 12 ＋ » (`.step`) pour les quantités.
class StepperQte extends StatelessWidget {
  const StepperQte({
    super.key,
    required this.valeur,
    required this.onMoins,
    required this.onPlus,
  });

  final int valeur;
  final VoidCallback onMoins;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final bleu = context.univers.bleu;
    Widget bouton(Widget contenu, VoidCallback f, String sem) => Semantics(
      button: true,
      label: sem,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: f,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.bordureChamp),
          ),
          child: contenu,
        ),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        bouton(
          Text('−', style: AppText.t(18, c: bleu, h: 1)),
          onMoins,
          'Moins',
        ),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 26),
          child: Text(
            '$valeur',
            textAlign: TextAlign.center,
            style: AppText.gras,
          ),
        ),
        const SizedBox(width: 8),
        bouton(AppIcon(AppIcons.plus, size: 14, color: bleu), onPlus, 'Plus'),
      ],
    );
  }
}

/// Élément qui a sa propre marge haute CSS (`margin: 14px 0 …`) : `FeuilleBase` la fusionne avec la marge basse de son
/// titre (en CSS, deux marges verticales adjacentes se fusionnent en la plus grande).
abstract interface class AMargeHaute {
  double get margeHaute;
}

/// Intertitre de feuille de filtres (`.titre-filtre`) : petites capitales grises.
///
/// `margeHaut` : 14 par défaut, 0 quand la maquette l'annule (`style="margin-top:0"`).
class TitreFiltre extends StatelessWidget implements AMargeHaute {
  const TitreFiltre(this.texte, {super.key, this.margeHaut = 14});
  final String texte;
  final double margeHaut;

  @override
  double get margeHaute => margeHaut;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(0, margeHaute, 0, 4),
    child: Text(
      texte.toUpperCase(),
      style: AppText.t(
        12,
        w: FontWeight.w800,
        c: AppColors.muted,
        espacement: 0.6,
      ),
    ),
  );
}

/// Intertitre de fiche (`.np-section`) : petites capitales colorées (violet par défaut, `bleu` possible).
class SectionTitre extends StatelessWidget implements AMargeHaute {
  const SectionTitre(
    this.texte, {
    super.key,
    this.couleur,
    this.margeHaut = 14,
  });

  final String texte;
  final Color? couleur;
  final double margeHaut;

  @override
  double get margeHaute => margeHaut;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(0, margeHaut, 0, 10),
    child: Text(
      texte.toUpperCase(),
      style: AppText.t(
        11.5,
        w: FontWeight.w800,
        c: couleur ?? context.univers.violet,
        espacement: 0.7,
      ),
    ),
  );
}

/// Ligne « clé : valeur » d'une fiche (`.ch`) : libellé gris à gauche, valeur en gras à droite.
class LigneCle extends StatelessWidget {
  const LigneCle(
    this.cle,
    this.valeur, {
    super.key,
    this.valeurWidget,
    this.onTap,
  });

  final String cle;
  final String valeur;

  /// Valeur personnalisée (lien, coche) à la place du texte gras.
  final Widget? valeurWidget;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ligne = Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 9),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.ligne)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(cle, style: AppText.t(14, c: AppColors.muted)),
          ),
          const SizedBox(width: 14),
          Flexible(
            child:
                valeurWidget ??
                Text(
                  valeur,
                  textAlign: TextAlign.right,
                  style: AppText.t(14, w: FontWeight.w700),
                ),
          ),
        ],
      ),
    );
    if (onTap == null) return ligne;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ligne,
    );
  }
}

/// Ligne d'écart ou d'étape (`.ecart`) : rond coloré avec symbole, titre, détail, élément à droite.
class LigneEcart extends StatelessWidget {
  const LigneEcart({
    super.key,
    required this.titre,
    this.detail,
    this.symbole = '✓',
    this.fond = AppColors.pVertFond,
    this.texte = AppColors.pVertTexte,
    this.trailing,
    this.premiere = false,
    this.tailleRond = 28,
  });

  final String titre;
  final String? detail;
  final String symbole;
  final Color fond;
  final Color texte;
  final Widget? trailing;

  /// Première ligne d'une liste : sans filet supérieur.
  final bool premiere;
  final double tailleRond;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: premiere
            ? null
            : const Border(top: BorderSide(color: AppColors.ligne)),
      ),
      child: Row(
        children: [
          Container(
            width: tailleRond,
            height: tailleRond,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: fond, shape: BoxShape.circle),
            child: Text(
              symbole,
              style: AppText.t(13, w: FontWeight.w800, c: texte),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titre, style: AppText.t(13.5, w: FontWeight.w700)),
                if (detail != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      detail!,
                      style: AppText.t(12, c: AppColors.muted),
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

/// Message d'erreur rouge pâle (`.erreur`).
class MessageErreur extends StatelessWidget {
  const MessageErreur(this.texte, {super.key, this.compact = false});
  final String texte;

  /// Version compacte (`padding: 8px 10px`).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: compact ? 6 : 12),
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.pRougeFond,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(texte, style: AppText.t(13, c: AppColors.pRougeTexte)),
    );
  }
}

/// Encadré « ⚠ Important » jaune (`.important`).
class EncadreImportant extends StatelessWidget {
  const EncadreImportant({super.key, required this.titre, required this.texte});
  final String titre;
  final String texte;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titre,
            style: AppText.t(
              13.5,
              w: FontWeight.w700,
              c: AppColors.pJauneTexte,
            ),
          ),
          const SizedBox(height: 3),
          Text(texte, style: AppText.t(12.5, c: AppColors.pJauneTexte)),
        ],
      ),
    );
  }
}

/// Encadré de consigne bleu pâle (`.consigne`) : titre bleu, texte gris, lien d'action.
class EncadreConsigne extends StatelessWidget {
  const EncadreConsigne({
    super.key,
    required this.titre,
    required this.texte,
    this.lien,
    this.onLien,
  });

  final String titre;
  final String texte;
  final String? lien;
  final VoidCallback? onLien;

  @override
  Widget build(BuildContext context) {
    final u = context.univers;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF5FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titre,
            style: AppText.t(13, w: FontWeight.w700, c: u.bleu),
          ),
          const SizedBox(height: 3),
          Text(texte, style: AppText.t(13, c: AppColors.muted)),
          if (lien != null && onLien != null)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: GestureDetector(
                onTap: onLien,
                child: Text(
                  lien!,
                  style: AppText.t(
                    13.5,
                    w: FontWeight.w700,
                    c: u.acc,
                    deco: TextDecoration.underline,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Astuce rouge pâle cliquable (`.astuce`), ex. « Le produit sera disponible à partir du 12 nov. ».
class Astuce extends StatelessWidget {
  const Astuce(this.texte, {super.key, this.onTap});
  final String texte;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final boite = Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        texte,
        style: AppText.t(12.5, w: FontWeight.w600, c: AppColors.pRougeTexte),
      ),
    );
    return onTap == null ? boite : GestureDetector(onTap: onTap, child: boite);
  }
}

/// Petit texte de pied de page (`.pied`).
class Pied extends StatelessWidget {
  const Pied(
    this.texte, {
    super.key,
    this.centre = false,
    this.margeHaut = 8,
    this.style,
  });

  final String texte;
  final bool centre;
  final double margeHaut;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: margeHaut),
    child: SizedBox(
      width: centre ? double.infinity : null,
      child: Text(
        texte,
        textAlign: centre ? TextAlign.center : TextAlign.start,
        style: style ?? AppText.pied,
      ),
    ),
  );
}

/// Un chiffre d'une ligne de chiffres (`.chiffres`) : « 14 visites ».
///
/// `valeur` (en gras) ou `libelle` peut être vide : l'élément n'affiche alors que l'autre partie, sans espace en trop
/// (`Chiffre('', 'Validé automatiquement')`).
class Chiffre {
  const Chiffre(this.valeur, this.libelle);
  final String valeur;
  final String libelle;
}

/// Ligne de chiffres en gras suivis d'un libellé (`.chiffres`) : le chiffre et le libellé sont tous deux gris,
/// car `.chiffres span{color:var(--muted)}` s'applique aussi au `<b>` qu'il contient.
class Chiffres extends StatelessWidget {
  const Chiffres(this.items, {super.key, this.margeHaut = 10});
  final List<Chiffre> items;
  final double margeHaut;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: margeHaut),
    // `display:flex; flex-wrap:wrap; gap:14px` : 14 dp entre éléments et entre rangées.
    child: Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        for (final c in items)
          Text.rich(
            TextSpan(
              children: [
                if (c.valeur.isNotEmpty)
                  TextSpan(
                    text: c.valeur,
                    style: AppText.t(
                      13,
                      w: FontWeight.w800,
                      c: AppColors.muted,
                    ),
                  ),
                if (c.libelle.isNotEmpty)
                  TextSpan(
                    text: c.valeur.isEmpty ? c.libelle : ' ${c.libelle}',
                    style: AppText.t(13, c: AppColors.muted),
                  ),
              ],
            ),
          ),
      ],
    ),
  );
}

/// Badge d'état avec point coloré (`.badge-v`) : « En cours », « À envoyer », « Envoyée ».
class BadgeEtat extends StatelessWidget {
  const BadgeEtat(this.libelle, {super.key, required this.couleur});
  final String libelle;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0x1f / 255),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            libelle,
            softWrap: false,
            style: AppText.t(12, w: FontWeight.w700, c: couleur),
          ),
        ],
      ),
    );
  }
}

/// Badge jaune d'entête de fiche (`.badge`) : « Prospect · En négo », « Client actif ».
class BadgeInfo extends StatelessWidget {
  const BadgeInfo(this.texte, {super.key});
  final String texte;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.pJauneFond,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        texte,
        style: AppText.t(12.5, w: FontWeight.w800, c: AppColors.pJauneTexte),
      ),
    );
  }
}

/// État d'une étape numérotée d'un parcours (visite, `.vnum`).
enum EtatNumero { aFaire, courante, faite }

/// Rond numéroté d'une étape (`.vnum`) : numéro, bleu si courante, vert avec ✓ si faite.
class NumeroEtape extends StatelessWidget {
  const NumeroEtape(this.numero, {super.key, required this.etat});
  final int numero;
  final EtatNumero etat;

  @override
  Widget build(BuildContext context) {
    final bleu = context.univers.bleu;
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: etat == EtatNumero.faite ? AppColors.ok : null,
        border: Border.all(
          color: switch (etat) {
            EtatNumero.faite => AppColors.ok,
            EtatNumero.courante => bleu,
            EtatNumero.aFaire => const Color(0xFFCBD2E0),
          },
          width: 1.5,
        ),
      ),
      child: Text(
        etat == EtatNumero.faite ? '✓' : '$numero',
        style: AppText.t(
          12,
          w: FontWeight.w700,
          c: switch (etat) {
            EtatNumero.faite => Colors.white,
            EtatNumero.courante => bleu,
            EtatNumero.aFaire => AppColors.muted,
          },
        ),
      ),
    );
  }
}
