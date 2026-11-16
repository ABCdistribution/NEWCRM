/// Formats d'affichage de la maquette : `eur`, `euros`, `eurD`, `kf`.
library;

const String _espaceInsecable = ' ';

/// Regroupe les milliers par une espace insécable (« 12 345 »).
String groupeMilliers(int n, {String separateur = _espaceInsecable}) {
  final neg = n < 0;
  final chiffres = n.abs().toString();
  final tampon = StringBuffer();
  for (var i = 0; i < chiffres.length; i++) {
    if (i > 0 && (chiffres.length - i) % 3 == 0) tampon.write(separateur);
    tampon.write(chiffres[i]);
  }
  return '${neg ? '-' : ''}$tampon';
}

/// Maquette `eur` : euros arrondis, milliers séparés (« 4 200 € », espaces insécables).
String eur(num v) => '${groupeMilliers(v.round())}$_espaceInsecable€';

/// Maquette `euros` : deux décimales, virgule (« 3,46 € »), sans séparateur de milliers.
String euros(num n) => '${n.toStringAsFixed(2).replaceAll('.', ',')} €';

/// Maquette `eurD` : `euros` avec milliers séparés (« 1 540,00 € »).
String eurD(num n) {
  final fixe = n.toStringAsFixed(2);
  final parties = fixe.split('.');
  final entier = int.parse(parties[0]);
  final negatifZero = parties[0] == '-0';
  return '${negatifZero ? '-0' : groupeMilliers(entier)},${parties[1]} €';
}

/// Maquette `kf` : un nombre en k€, virgule décimale, sans « .0 » (180 → « 180 », 1.5 → « 1,5 »).
String kf(num n) {
  if (n == n.roundToDouble()) return n.round().toString();
  return n.toString().replaceAll('.', ',');
}

/// Pluriel simple : « 1 client », « 2 clients ».
String pluriel(int n, String singulier, [String? plurielForme]) =>
    '$n ${n > 1 ? (plurielForme ?? '${singulier}s') : singulier}';
