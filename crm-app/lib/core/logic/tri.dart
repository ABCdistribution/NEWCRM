/// Tri alphabétique français (équivalent de `localeCompare` de la maquette).
library;

const String _avec = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ';
const String _sans = 'aaaaaaceeeeiiiinooooouuuuyyoa';

int _categorie(int unit) {
  // ponctuation et espaces avant les chiffres, avant les lettres (ordre ICU).
  if (unit >= 48 && unit <= 57) return 1;
  if ((unit >= 97 && unit <= 122)) return 2;
  return 0;
}

String _plie(String s) {
  final b = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    final c = String.fromCharCode(r);
    final i = _avec.indexOf(c);
    b.write(i >= 0 ? _sans[i] : c);
  }
  return b.toString();
}

/// Compare deux libellés sans tenir compte de la casse ni des accents ;
/// la ponctuation (« – », espace) passe avant les chiffres, puis les lettres.
int compareFr(String a, String b) {
  final x = _plie(a);
  final y = _plie(b);
  final n = x.length < y.length ? x.length : y.length;
  for (var i = 0; i < n; i++) {
    final cx = x.codeUnitAt(i);
    final cy = y.codeUnitAt(i);
    if (cx == cy) continue;
    final gx = _categorie(cx);
    final gy = _categorie(cy);
    if (gx != gy) return gx.compareTo(gy);
    return cx.compareTo(cy);
  }
  return x.length.compareTo(y.length);
}

/// Tri stable (`List.sort` de Dart ne l'est pas) : à clés égales, l'ordre d'origine est conservé.
List<T> triStable<T>(Iterable<T> source, int Function(T a, T b) comparer) {
  final indexes = source.toList().asMap().entries.toList();
  indexes.sort((a, b) {
    final c = comparer(a.value, b.value);
    return c != 0 ? c : a.key.compareTo(b.key);
  });
  return indexes.map((e) => e.value).toList();
}
