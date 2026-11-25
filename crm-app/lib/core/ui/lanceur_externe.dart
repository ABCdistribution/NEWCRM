import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'toast.dart';

/// Ouvre une adresse (`tel:`, `mailto:`, carte) dans l'application du téléphone qui la gère.
///
/// Interface séparée du paquet `url_launcher` pour que les tests la remplacent par un faux lanceur
/// (`lanceurExterneProvider.overrideWithValue(...)`).
abstract interface class LanceurExterne {
  /// Vrai si une application a pris en charge l'adresse.
  Future<bool> ouvrir(Uri uri);
}

/// Lanceur réel : une application externe (téléphone, messagerie, cartes).
class LanceurUrlLauncher implements LanceurExterne {
  const LanceurUrlLauncher();

  @override
  Future<bool> ouvrir(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}

final lanceurExterneProvider = Provider<LanceurExterne>(
  (ref) => const LanceurUrlLauncher(),
);

/// `tel:` du numéro, nul s'il n'en reste pas assez de chiffres. Espaces, points, tirets et parenthèses sont retirés ;
/// le « + » initial est gardé, « 00 » devient « + ».
Uri? uriAppel(String? numero) {
  final brut = numero?.trim();
  if (brut == null || brut.isEmpty) return null;
  var chiffres = brut.replaceAll(RegExp(r'\D'), '');
  var international = brut.startsWith('+');
  if (!international && chiffres.startsWith('00')) {
    chiffres = chiffres.substring(2);
    international = true;
  }
  if (chiffres.length < 3) return null;
  return Uri(scheme: 'tel', path: international ? '+$chiffres' : chiffres);
}

final RegExp _formeMail = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

/// `mailto:` de l'adresse, nul si elle n'a pas la forme d'un e-mail.
Uri? uriMail(String? adresse) {
  final a = adresse?.trim();
  if (a == null || a.length > 254 || !_formeMail.hasMatch(a)) return null;
  return Uri(scheme: 'mailto', path: a);
}

/// Itinéraire vers l'adresse : `geo:0,0?q=…` sur Android (l'appli de cartes au choix), lien Google Maps ailleurs.
/// Nul si l'adresse est vide.
Uri? uriItineraire(String? adresse, {TargetPlatform? plateforme}) {
  final a = adresse?.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (a == null || a.isEmpty || a == '—') return null;
  final p = plateforme ?? defaultTargetPlatform;
  if (p == TargetPlatform.android) {
    return Uri.parse('geo:0,0?q=${Uri.encodeComponent(a)}');
  }
  return Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': a});
}

/// Lance `uri` ; un toast sobre signale l'échec (aucune application pour la gérer). Vrai si l'application s'est ouverte.
Future<bool> lancerExterne(
  BuildContext context,
  LanceurExterne lanceur,
  Uri uri,
) async {
  final ok = await lanceur.ouvrir(uri);
  if (!ok && context.mounted) {
    AppToast.show(context, "Impossible d'ouvrir l'application.");
  }
  return ok;
}
