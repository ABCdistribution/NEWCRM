import 'dart:math' as math;

/// Identifiant d'idempotence d'une création envoyée au CRM (`idApk`, 64 caractères au plus) : un UUID v4, tiré une
/// fois par soumission de formulaire et gardé pour les nouveaux essais.
String genererIdApkUuid([math.Random? hasard]) {
  final r = hasard ?? math.Random.secure();
  final o = List<int>.generate(16, (_) => r.nextInt(256));
  o[6] = (o[6] & 0x0f) | 0x40;
  o[8] = (o[8] & 0x3f) | 0x80;
  final h = o.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}
