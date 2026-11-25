import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/erreur_api.dart';
import '../auth/session.dart';
import '../data/journal_contacts.dart';
import '../db/app_database.dart';
import '../db/base_provider.dart';
import 'catalogue_provider.dart';

const _domaineJournal = 'journal_contacts';

List<EntreeJournalContact>? _depuisCache(String? brut) {
  if (brut == null) return null;
  try {
    return journalContactsDepuisJson(jsonDecode(brut));
  } catch (_) {
    return null;
  }
}

/// Derniers appels et e-mails d'un client du CRM (`GET /clients/:id/journal-contacts`) : la copie locale d'abord (hors
/// connexion), puis la version fraîche. Réseau coupé ou accès refusé : la copie locale reste. À ne lire que pour un rôle
/// autorisé (`peutEcrireMagasin`) ; relu par la file d'envoi une fois un appel ou un e-mail parti.
final journalContactsProvider =
    StreamProvider.family<List<EntreeJournalContact>, String>((ref, id) async* {
      AppDatabase? base;
      try {
        base = ref.read(baseLocaleProvider);
      } catch (_) {}
      if (base != null) {
        final copie = _depuisCache(
          await base.enregistrement(_domaineJournal, id),
        );
        if (copie != null) yield copie;
      }
      final api = ref.read(apiClientProvider);
      try {
        final reponse = await api.get(
          '/clients/${Uri.encodeComponent(id)}/journal-contacts',
        );
        if (reponse is! Map<String, dynamic>) return;
        if (base != null) {
          await base.ecrireEnregistrement(
            _domaineJournal,
            id,
            jsonEncode(reponse),
          );
        }
        yield journalContactsDepuisJson(reponse);
      } on ErreurApi catch (e) {
        if (e.type == TypeErreurApi.sessionExpiree) {
          await ref.read(sessionProvider.notifier).deconnecter();
        }
      }
    });
