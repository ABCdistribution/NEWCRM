import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/erreur_api.dart';
import '../auth/session.dart';
import '../data/planning_serveur.dart';
import '../db/app_database.dart';
import '../db/base_provider.dart';
import '../logic/dates.dart';
import '../models/models.dart';
import 'catalogue_provider.dart';

/// Données chargées à l'ouverture d'un écran : planning d'un membre de l'équipe, rapport d'une semaine. Même cycle que
/// les fiches client et prospect : la copie locale d'abord (hors connexion), puis la version fraîche du CRM. Le périmètre
/// est celui que renvoie l'API ; un refus ou une panne réseau laisse la copie locale, ou « rien » sans copie.

const _domainePlanning = 'planning_equipe';
const _domaineRapportEquipe = 'rapport_equipe';
const _domaineRapportPerso = 'rapport_perso';

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

/// « 2026-11-02 » (lundi) en date locale, ou null.
DateTime? lundiDepuisIso(String iso) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(iso);
  if (m == null) return null;
  return DateTime(
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
  );
}

/// Lit la copie locale (`lire` appliqué au JSON rangé), puis télécharge et range la réponse fraîche. Émet une valeur
/// nulle à la fin quand rien n'a pu être lu (ni copie ni réponse), pour que l'écran sorte de l'attente.
Stream<T?> _avecCopie<T>(
  Ref ref, {
  required String domaine,
  required String id,
  required Future<Object?> Function(ApiLecture api) charger,
  required T? Function(Object? brut) lire,
}) async* {
  AppDatabase? base;
  try {
    base = ref.read(baseLocaleProvider);
  } catch (_) {}
  var emis = false;
  if (base != null) {
    final copie = await base.enregistrement(domaine, id);
    if (copie != null) {
      try {
        final v = lire(jsonDecode(copie));
        if (v != null) {
          emis = true;
          yield v;
        }
      } catch (_) {}
    }
  }
  try {
    final reponse = await charger(ref.read(apiClientProvider));
    if (base != null) {
      await base.ecrireEnregistrement(domaine, id, jsonEncode(reponse));
    }
    final v = lire(reponse);
    if (v != null) {
      emis = true;
      yield v;
    }
  } on ErreurApi catch (e) {
    if (e.type == TypeErreurApi.sessionExpiree) {
      await ref.read(sessionProvider.notifier).deconnecter();
    }
  } catch (_) {}
  if (!emis) yield null;
}

/// Planning d'un membre de l'équipe sur la fenêtre de quelques semaines autour de la semaine courante.
///
/// Un promoteur (`promoteur` vrai) : ses visites planifiées (`GET /plannings`) ; un chef de secteur ou un directeur
/// régional : sa tournée (`GET /tournees/user/:id`, lecture seule). Nul quand rien n'est lisible.
final planningUtilisateurProvider =
    StreamProvider.family<List<EtapePlanning>?, ({String userId, bool promoteur})>((
      ref,
      cle,
    ) {
      if (!_uuid.hasMatch(cle.userId)) return Stream.value(null);
      final lundi = DemoTemps.lundi;
      final f = fenetrePlanning(lundi);
      final id = Uri.encodeComponent(cle.userId);
      return _avecCopie<List<EtapePlanning>>(
        ref,
        domaine: _domainePlanning,
        id: cle.userId,
        charger: (api) => cle.promoteur
            ? api.get(
                '/plannings',
                query: {
                  'promoteurId': cle.userId,
                  'debut': f.debut,
                  'fin': f.fin,
                },
              )
            : api.get(
                '/tournees/user/$id',
                query: {'debut': f.debut, 'fin': f.fin},
              ),
        lire: (brut) {
          final lignes = brut is Map ? brut['etapes'] : brut;
          if (lignes is! List) return null;
          final l = [
            for (final j in lignes.whereType<Map<String, dynamic>>())
              ?(brut is Map
                  ? etapeDepuisTournee(j, lundi)
                  : etapeDepuisPlanning(j, lundi)),
          ];
          l.sort((a, b) {
            final c = (a.sem ?? 0).compareTo(b.sem ?? 0);
            if (c != 0) return c;
            final d = a.jour.compareTo(b.jour);
            return d != 0 ? d : a.heure.compareTo(b.heure);
          });
          return l;
        },
      );
    });

/// Rapport d'activité d'une semaine d'un chef de secteur ou d'un directeur régional (`GET /rapports/:userId`) :
/// réservé à la direction, aux directeurs régionaux et aux administrateurs (un refus donne null).
final rapportEquipeProvider =
    StreamProvider.family<RapportEquipe?, ({String userId, String lundi})>((
      ref,
      cle,
    ) {
      final lundi = lundiDepuisIso(cle.lundi);
      if (!_uuid.hasMatch(cle.userId) || lundi == null) {
        return Stream.value(null);
      }
      return _avecCopie<RapportEquipe>(
        ref,
        domaine: _domaineRapportEquipe,
        id: '${cle.userId}|${cle.lundi}',
        charger: (api) => api.get(
          '/rapports/${Uri.encodeComponent(cle.userId)}',
          query: {'semaine': cle.lundi},
        ),
        lire: (brut) => rapportEquipeDepuisJson(brut, lundi),
      );
    });

/// Rapport d'une semaine passée de l'utilisateur lui-même : prévision enregistrée (`/tournees/semaine/prevue`) et
/// tournée réalisée (`/tournees/me`). La consultation `/rapports` n'est pas ouverte à son auteur.
final rapportPersonnelProvider = StreamProvider.family<RapportEquipe?, String>((
  ref,
  lundiIso,
) {
  final lundi = lundiDepuisIso(lundiIso);
  if (lundi == null) return Stream.value(null);
  final fin = isoJour(DateTime(lundi.year, lundi.month, lundi.day + 7));
  return _avecCopie<RapportEquipe>(
    ref,
    domaine: _domaineRapportPerso,
    id: lundiIso,
    charger: (api) async => {
      'semaine': await api.get('/tournees/semaine', query: {'semaine': lundiIso}),
      'prevue': await api.get(
        '/tournees/semaine/prevue',
        query: {'semaine': lundiIso},
      ),
      'etapes': await api.get(
        '/tournees/me',
        query: {'debut': lundiIso, 'fin': fin},
      ),
    },
    lire: (brut) => rapportPersonnelDepuisJson(brut, lundi),
  );
});
