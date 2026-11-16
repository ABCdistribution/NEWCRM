import 'package:flutter/material.dart';

import '../../../core/data/fiche_client.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/ui/ui.dart';

/// Onglets de la fiche client (maquette : `ficheMag` l.1821). Le promoteur a « Aperçu », « Contacts », « Commandes »,
/// « Notes » ; l'encadrement « Suivi », « Commandes », « Contacts », « Infos ».
enum OngletMagasin {
  apercu('Aperçu'),
  suivi('Suivi'),
  commandes('Commandes'),
  contacts('Contacts'),
  notes('Notes'),
  infos('Infos');

  const OngletMagasin(this.libelle);
  final String libelle;

  /// Onglets proposés selon le rôle (le premier est celui qui s'ouvre).
  static List<OngletMagasin> pour({required bool promoteur}) => promoteur
      ? const [apercu, contacts, commandes, notes]
      : const [suivi, commandes, contacts, infos];
}

/// Fond du rond d'icône des événements (`#EEF0F8`).
const Color _fondIconeSuivi = Color(0xFFEEF0F8);

/// Notes du client (onglet « Notes » du promoteur) : textes de la maquette.
const List<String> notesDuClient = [
  'Nouveau chef de rayon arrivé, à rencontrer · 10 sept.',
  'Demande une implantation tête de gondole · 2 sept.',
];

/// Carte blanche qui porte le contenu d'un onglet (`.tl`) : même décor que `Timeline`, contenu libre.
class CarteOnglet extends StatelessWidget {
  const CarteOnglet({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: context.univers.ombreCarte,
      ),
      child: Column(children: children),
    );
  }
}

/// Un événement d'un onglet (`.tl-ev`) : rond d'icône de 32 px, contenu libre, trait vertical vers l'événement suivant.
class EvenementOnglet extends StatelessWidget {
  const EvenementOnglet({
    super.key,
    required this.enfant,
    this.icone,
    this.fondIcone = _fondIconeSuivi,
    this.onTap,
    this.dernier = false,
  });

  final Widget enfant;

  /// Emoji ou caractère du rond ; nul = pas de rond (onglet « Infos »).
  final String? icone;
  final Color fondIcone;
  final VoidCallback? onTap;

  /// Dernier événement de la carte : pas de trait en dessous.
  final bool dernier;

  @override
  Widget build(BuildContext context) {
    final contenu = Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icone != null) ...[
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: fondIcone,
                shape: BoxShape.circle,
              ),
              child: Text(icone!, style: AppText.t(15)),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(child: enfant),
        ],
      ),
    );
    final avecTrait = Stack(
      children: [
        contenu,
        if (!dernier)
          Positioned(
            left: 15,
            top: 34,
            bottom: 2,
            child: Container(width: 2, color: AppColors.ligne),
          ),
      ],
    );
    if (onTap == null) return avecTrait;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: avecTrait,
    );
  }
}

/// Onglet « Suivi » (« Aperçu » pour le promoteur) : prochaine visite, dernière commande, alerte, visite et note
/// de la maquette ; la dernière commande vient du store.
class OngletSuivi extends StatelessWidget {
  const OngletSuivi({super.key, required this.derniereCommande});

  /// Commande la plus récente du client, s'il en a une.
  final Commande? derniereCommande;

  @override
  Widget build(BuildContext context) {
    final c = derniereCommande;
    return Timeline([
      const TimelineItem(
        icone: '📅',
        titre: 'Visite chef de secteur prévue',
        date: 'lun. 2 nov.',
        detail: 'Relance baisse de CA avec le chef de rayon',
      ),
      if (c != null)
        TimelineItem(
          icone: '🛒',
          titre: 'Commande ${c.id}',
          date: c.date,
          detail: '${c.ht} HT · ${c.statut.libelle}',
        ),
      const TimelineItem(
        icone: '⚠️',
        titre: 'Alerte rupture',
        date: '22 oct.',
        detail: 'Sérum éclat 30 ml absent du rayon',
      ),
      const TimelineItem(
        icone: '📍',
        titre: 'Visite promoteur',
        date: '19 sept.',
        detail: 'Relevé linéaire · 12 facings · photos',
      ),
      const TimelineItem(
        icone: '✎',
        titre: 'Note',
        date: '10 sept.',
        detail: 'Nouveau chef de rayon arrivé, à rencontrer',
      ),
    ]);
  }
}

/// Onglet « Commandes » : les commandes du client, les plus récentes d'abord, avec leur état de livraison ;
/// un appui ouvre le suivi du transport. Sans commande : « Aucune commande pour ce client. ».
class OngletCommandes extends StatelessWidget {
  const OngletCommandes({
    super.key,
    required this.commandes,
    required this.onCommande,
  });

  final List<Commande> commandes;
  final ValueChanged<Commande> onCommande;

  @override
  Widget build(BuildContext context) {
    if (commandes.isEmpty) {
      return const CarteOnglet(
        children: [Vide('Aucune commande pour ce client.')],
      );
    }
    return CarteOnglet(
      children: [
        for (var i = 0; i < commandes.length; i++)
          EvenementOnglet(
            icone: '🛒',
            fondIcone: AppColors.pBleuFond,
            dernier: i == commandes.length - 1,
            onTap: () => onCommande(commandes[i]),
            enfant: _LigneCommande(commandes[i]),
          ),
      ],
    );
  }
}

class _LigneCommande extends StatelessWidget {
  const _LigneCommande(this.commande);

  final Commande commande;

  @override
  Widget build(BuildContext context) {
    final c = commande;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                '${c.ht} HT',
                style: AppText.t(13.5, w: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            Pastille(
              c.statut.libelle,
              variante: c.statut == StatutLivraison.livree
                  ? VariantePastille.vert
                  : VariantePastille.jaune,
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            '${c.id} · ${c.date}${c.estEdi ? ' · EDI' : ''}',
            style: AppText.t(12.5, c: AppColors.muted),
          ),
        ),
      ],
    );
  }
}

/// Onglet « Contacts » : les contacts du client au CRM ; sans contact (ou en démonstration), « Aucun contact ».
class OngletContacts extends StatelessWidget {
  const OngletContacts({super.key, this.contacts = const []});

  final List<ContactClient> contacts;

  @override
  Widget build(BuildContext context) {
    if (contacts.isEmpty) {
      return const CarteOnglet(children: [Vide('Aucun contact renseigné.')]);
    }
    return CarteOnglet(
      children: [
        for (var i = 0; i < contacts.length; i++)
          EvenementOnglet(
            icone: '👤',
            dernier: i == contacts.length - 1,
            enfant: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contacts[i].nom, style: AppText.t(14, w: FontWeight.w700)),
                for (final ligne in [
                  contacts[i].poste,
                  contacts[i].telephone,
                  contacts[i].mail,
                ])
                  if (ligne != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        ligne,
                        style: AppText.t(12.5, c: AppColors.muted),
                      ),
                    ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Onglet « Suivi » / « Aperçu » d'un client du CRM : ses dernières visites, commandes et notes, sans rien inventer.
class OngletSuiviReel extends StatelessWidget {
  const OngletSuiviReel({
    super.key,
    required this.fiche,
    required this.commandes,
  });

  final FicheClient? fiche;
  final List<Commande> commandes;

  @override
  Widget build(BuildContext context) {
    final f = fiche;
    final items = <TimelineItem>[
      if (f != null)
        for (final v in f.visites.take(5))
          TimelineItem(
            icone: '📍',
            titre: 'Visite',
            date: v.date,
            detail: [
              if (v.par != null) v.par!,
              if (v.photos > 0) '${v.photos} photos',
            ].join(' · '),
          ),
      for (final c in commandes.take(5))
        TimelineItem(
          icone: '🛒',
          titre: 'Commande ${c.id}',
          date: c.date,
          detail: '${c.ht} HT · ${c.statut.libelle}',
        ),
      if (f != null)
        for (final n in f.notes.take(3))
          TimelineItem(
            icone: '✎',
            titre: 'Note',
            date: n.date,
            detail: n.texte,
          ),
    ];
    if (items.isEmpty) {
      return const CarteOnglet(children: [Vide('Aucun historique.')]);
    }
    return Timeline(items);
  }
}

/// Onglet « Notes » d'un client du CRM.
class OngletNotesReel extends StatelessWidget {
  const OngletNotesReel({super.key, required this.notes});

  final List<NoteClient> notes;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return const CarteOnglet(children: [Vide('Aucune note.')]);
    }
    return CarteOnglet(
      children: [
        for (var i = 0; i < notes.length; i++)
          EvenementOnglet(
            icone: '✎',
            dernier: i == notes.length - 1,
            enfant: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notes[i].texte,
                  style: AppText.t(13.5, w: FontWeight.w700),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    [
                      if (notes[i].date.isNotEmpty) notes[i].date,
                      if (notes[i].auteur != null) notes[i].auteur!,
                    ].join(' · '),
                    style: AppText.t(12.5, c: AppColors.muted),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Onglet « Notes » (promoteur) : les deux notes de la maquette.
class OngletNotes extends StatelessWidget {
  const OngletNotes({super.key});

  @override
  Widget build(BuildContext context) {
    return CarteOnglet(
      children: [
        for (var i = 0; i < notesDuClient.length; i++)
          EvenementOnglet(
            icone: '✎',
            dernier: i == notesDuClient.length - 1,
            enfant: Text(
              notesDuClient[i],
              style: AppText.t(13.5, w: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}

/// Onglet « Infos » (encadrement) : adresse et classe du client.
class OngletInfos extends StatelessWidget {
  const OngletInfos({super.key, required this.magasin, this.fiche});

  final Magasin magasin;

  /// Coordonnées et rattachements du client au CRM (clients réels).
  final FicheClient? fiche;

  @override
  Widget build(BuildContext context) {
    final detail = AppText.t(12.5, c: AppColors.muted);
    return CarteOnglet(
      children: [
        EvenementOnglet(
          dernier: true,
          enfant: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Adresse', style: AppText.t(14, w: FontWeight.w700)),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(magasin.adresse, style: detail),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text('Classe', style: AppText.t(14, w: FontWeight.w700)),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(magasin.classe, style: detail),
              ),
              for (final (titre, valeur) in [
                ('Téléphone', fiche?.telephone),
                ('Mail', fiche?.mail),
                ('Centrale', fiche?.centrale),
                ('Secteur', fiche?.secteur),
                (
                  'Commerciaux',
                  fiche == null || fiche!.commerciaux.isEmpty
                      ? null
                      : fiche!.commerciaux.join(', '),
                ),
                ('Périodicité', fiche?.periodicite),
              ])
                if (valeur != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      titre,
                      style: AppText.t(14, w: FontWeight.w700),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(valeur, style: detail),
                  ),
                ],
            ],
          ),
        ),
      ],
    );
  }
}
