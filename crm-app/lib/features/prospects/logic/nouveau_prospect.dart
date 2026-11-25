/// Formulaire « Nouveau prospect » : brouillon, validation et construction du prospect.
///
/// Maquette : `nouveauProspect` (l.1718-1736), `lireFP` (l.1715) et l'action `np-creer` (l.2007-2021).
library;

import '../../../core/api/erreur_api.dart';
import '../../../core/data/data.dart';
import '../../../core/models/models.dart';

/// Champs du formulaire, tels que saisis (textes bruts, avant validation).
class BrouillonProspect {
  const BrouillonProspect({
    this.enseigne = '',
    this.raison = '',
    this.ville = '',
    this.cp = '',
    this.tel = '',
    this.email = '',
    this.secteur = '',
    this.source = '',
    this.classe = '',
    this.etape = StatutProspect.nouveau,
    this.proba = '',
    this.pot = '',
  });

  final String enseigne;
  final String raison;
  final String ville;
  final String cp;
  final String tel;
  final String email;

  /// Code du secteur (« s1 »…) ou vide ; saisi mais sans effet sur le prospect créé, comme dans la maquette.
  final String secteur;

  /// Code de la source (« SALON »…) ou vide.
  final String source;

  /// Classe du client (« A » à « G ») ou vide.
  final String classe;
  final StatutProspect etape;

  /// Probabilité (%) saisie, vide = celle de l'étape.
  final String proba;

  /// Potentiel CA/an en euros saisi, vide = 0.
  final String pot;

  BrouillonProspect copyWith({
    String? enseigne,
    String? raison,
    String? ville,
    String? cp,
    String? tel,
    String? email,
    String? secteur,
    String? source,
    String? classe,
    StatutProspect? etape,
    String? proba,
    String? pot,
  }) {
    return BrouillonProspect(
      enseigne: enseigne ?? this.enseigne,
      raison: raison ?? this.raison,
      ville: ville ?? this.ville,
      cp: cp ?? this.cp,
      tel: tel ?? this.tel,
      email: email ?? this.email,
      secteur: secteur ?? this.secteur,
      source: source ?? this.source,
      classe: classe ?? this.classe,
      etape: etape ?? this.etape,
      proba: proba ?? this.proba,
      pot: pot ?? this.pot,
    );
  }
}

/// Étapes proposées à la création et leur libellé dans la liste (`liste('etape', …)`).
const Map<StatutProspect, String> etapesCreation = {
  StatutProspect.nouveau: 'Nouveau',
  StatutProspect.contacte: 'Contacté',
  StatutProspect.visite: 'Visite',
  StatutProspect.proposition: 'Proposition',
  StatutProspect.negociation: 'Négociation',
  StatutProspect.gagne: 'Gagné',
};

/// Classes proposées (« Classe A » à « Classe G »).
const List<String> classesCreation = ['A', 'B', 'C', 'D', 'E', 'F', 'G'];

final RegExp _formeEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final RegExp _entierPositif = RegExp(r'^\d+$');

/// Lit le potentiel saisi en euros : nul s'il est vide, `double.nan` s'il n'est pas un nombre (`Number(…)` de la maquette,
/// avec la virgule comme séparateur décimal).
double? lirePotentiel(String saisie) {
  final t = saisie.trim();
  if (t.isEmpty) return null;
  return double.tryParse(t.replaceFirst(',', '.')) ?? double.nan;
}

/// Erreurs de validation par champ (clés : `enseigne`, `raison`, `ville`, `cp`, `tel`, `email`, `proba`, `pot`) ;
/// vide = formulaire valide. Les longueurs sont celles que le CRM accepte.
Map<String, String> validerProspect(BrouillonProspect f) {
  final erreurs = <String, String>{};
  String? trop(String v, int max) =>
      v.trim().length > max ? '$max caractères au plus' : null;
  if (f.enseigne.trim().isEmpty) {
    erreurs['enseigne'] = 'Enseigne requise';
  } else if (trop(f.enseigne, 200) case final m?) {
    erreurs['enseigne'] = m;
  }
  if (f.raison.trim().isEmpty) {
    erreurs['raison'] = 'Raison sociale requise';
  } else if (trop(f.raison, 200) case final m?) {
    erreurs['raison'] = m;
  }
  if (trop(f.ville, 100) case final m?) erreurs['ville'] = m;
  if (trop(f.cp, 10) case final m?) erreurs['cp'] = m;
  if (trop(f.tel, 20) case final m?) erreurs['tel'] = m;
  if (f.email.trim().isNotEmpty && !_formeEmail.hasMatch(f.email.trim())) {
    erreurs['email'] = 'Email invalide';
  } else if (trop(f.email, 200) case final m?) {
    erreurs['email'] = m;
  }
  final proba = f.proba.trim();
  if (proba.isNotEmpty &&
      !(_entierPositif.hasMatch(proba) &&
          (int.tryParse(proba) ?? 101) <= 100)) {
    erreurs['proba'] = 'Entre 0 et 100';
  }
  final pot = lirePotentiel(f.pot);
  if (pot != null && (pot.isNaN || pot < 0 || pot.isInfinite)) {
    erreurs['pot'] = 'Montant invalide';
  }
  return erreurs;
}

/// Corps de `POST /prospects/apk` pour un formulaire valide. Les champs vides ne sont pas envoyés : le CRM applique
/// alors ses valeurs par défaut (probabilité de l'étape, par exemple). Le prospect est assigné à son créateur.
Map<String, Object?> corpsProspect(
  BrouillonProspect f, {
  required String idApk,
}) {
  String? texte(String v) => v.trim().isEmpty ? null : v.trim();
  final proba = texte(f.proba);
  final pot = lirePotentiel(f.pot);
  return {
    'idApk': idApk,
    'raisonSociale': f.raison.trim(),
    'enseigne': f.enseigne.trim(),
    'codePostal': ?texte(f.cp),
    'ville': ?texte(f.ville),
    'telephone': ?texte(f.tel),
    'email': ?texte(f.email),
    'statut': f.etape.code,
    if (proba != null) 'probabilite': int.parse(proba),
    'potentielCaAnnuel': ?pot,
    if (f.source.isNotEmpty) 'source': f.source,
    if (f.classe.isNotEmpty) 'niveauClass': f.classe,
  };
}

/// Message affiché quand la création échoue : celui de l'API quand elle en donne un, sinon un texte selon le statut.
String messageErreurProspect(ErreurApi e) {
  if (e.detail != null || e.type != TypeErreurApi.inattendue) return e.message;
  return switch (e.statut) {
    400 => 'Ces informations sont refusées par le CRM. Vérifiez la saisie.',
    404 => 'Secteur introuvable dans votre périmètre.',
    409 => 'Ce prospect a déjà été créé.',
    _ => e.message,
  };
}

/// Identifiant du nouveau prospect : « p » suivi du nombre de prospects visibles plus un, décalé s'il est déjà pris
/// (la maquette ne vérifiait pas et pouvait en attribuer un qui existait).
String prochainIdProspect(List<Prospect> existants) {
  var n = existants.length + 1;
  while (existants.any((p) => p.id == 'p$n')) {
    n++;
  }
  return 'p$n';
}

/// Prospect créé à partir d'un formulaire valide : « En attente d'envoi », rattaché au secteur s1 et à `creePar`.
Prospect construireProspect(
  BrouillonProspect f, {
  required String id,
  required String creePar,
}) {
  final enseigne = f.enseigne.trim();
  final ville = f.ville.trim();
  final pot = lirePotentiel(f.pot);
  final proba = f.proba.trim().isNotEmpty
      ? int.parse(f.proba.trim())
      : f.etape.probaParDefaut;
  final source = sourcesProspect[f.source]?.toLowerCase() ?? 'non précisée';
  return Prospect(
    id: id,
    nom: ville.isEmpty ? enseigne : '$enseigne – $ville',
    raison: f.raison.trim().toUpperCase(),
    classe: f.classe.isEmpty ? '—' : f.classe,
    cp: [f.cp.trim(), ville].where((x) => x.isNotEmpty).join(' '),
    statut: f.etape,
    // Euros → k€ à une décimale ; `Math.round` arrondit les moitiés vers le haut.
    pot: pot == null ? 0 : ((pot / 100 + 0.5).floorToDouble()) / 10,
    proba: proba,
    secteurId: 's1',
    cs: creePar,
    attente: true,
    timeline: [
      EvenementProspect(
        icone: IconeEvenement.plus,
        couleur: 0xFF6B7280,
        titre: 'Fiche créée',
        date: 'auj.',
        detail: 'Source : $source · par $creePar',
      ),
    ],
  );
}
