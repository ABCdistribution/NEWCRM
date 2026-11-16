/// Encodage des codes-barres (logique pure) : EAN-13, UPC-A, EAN-8 et, pour tout autre numéro, Code 128.
///
/// Même règle que la fiche produit du web : un code-barres est dessiné dès que la valeur est encodable, et il encode
/// toujours exactement le numéro affiché (jamais un faux EAN).
library;

/// Barre continue d'un symbole : position et largeur en modules.
typedef Barre = ({int x, int largeur});

/// Barres d'un symbole décrit module par module (« 1 » = barre, « 0 » = espace), modules noirs fusionnés.
List<Barre> barresDeModules(String modules) {
  final barres = <Barre>[];
  var debut = -1;
  for (var i = 0; i <= modules.length; i++) {
    final noir = i < modules.length && modules[i] == '1';
    if (noir && debut < 0) debut = i;
    if (!noir && debut >= 0) {
      barres.add((x: debut, largeur: i - debut));
      debut = -1;
    }
  }
  return barres;
}

// --- EAN-13 / EAN-8 ---------------------------------------------------------------------------------------------

const _garde = '101';
const _centre = '01010';

/// Jeu L (parité impaire), chiffres 0 à 9.
const _jeuL = [
  '0001101',
  '0011001',
  '0010011',
  '0111101',
  '0100011',
  '0110001',
  '0101111',
  '0111011',
  '0110111',
  '0001011',
];

/// Jeu G (parité paire), chiffres 0 à 9.
const _jeuG = [
  '0100111',
  '0110011',
  '0011011',
  '0100001',
  '0011101',
  '0111001',
  '0000101',
  '0010001',
  '0001001',
  '0010111',
];

/// Jeu R (côté droit), chiffres 0 à 9.
const _jeuR = [
  '1110010',
  '1100110',
  '1101100',
  '1000010',
  '1011100',
  '1001110',
  '1010000',
  '1000100',
  '1001000',
  '1110100',
];

/// Jeux des six chiffres de gauche selon le premier chiffre de l'EAN-13.
const _parite = [
  'LLLLLL',
  'LLGLGG',
  'LLGGLG',
  'LLGGGL',
  'LGLLGG',
  'LGGLLG',
  'LGGGLL',
  'LGLGLG',
  'LGLGGL',
  'LGGLGL',
];

/// Clé de contrôle des douze premiers chiffres d'un EAN-13 ; null si ce ne sont pas douze chiffres.
int? cleEan13(String douze) {
  if (!RegExp(r'^\d{12}$').hasMatch(douze)) return null;
  var somme = 0;
  for (var i = 0; i < 12; i++) {
    somme += int.parse(douze[i]) * (i.isEven ? 1 : 3);
  }
  return (10 - somme % 10) % 10;
}

/// Vrai pour exactement 13 chiffres dont la clé de contrôle est correcte.
bool estEan13(String? code) =>
    code != null &&
    RegExp(r'^\d{13}$').hasMatch(code) &&
    cleEan13(code.substring(0, 12)) == int.parse(code[12]);

/// Les 95 modules d'un EAN-13 valide, ou null.
String? modulesEan13(String? code) {
  if (!estEan13(code)) return null;
  final parite = _parite[int.parse(code![0])];
  final gauche = StringBuffer();
  for (var i = 0; i < 6; i++) {
    final chiffre = int.parse(code[i + 1]);
    gauche.write(parite[i] == 'L' ? _jeuL[chiffre] : _jeuG[chiffre]);
  }
  final droite = StringBuffer();
  for (var i = 7; i < 13; i++) {
    droite.write(_jeuR[int.parse(code[i])]);
  }
  return '$_garde$gauche$_centre$droite$_garde';
}

/// Clé de contrôle des sept premiers chiffres d'un EAN-8 ; null si ce ne sont pas sept chiffres.
int? cleEan8(String sept) {
  if (!RegExp(r'^\d{7}$').hasMatch(sept)) return null;
  var somme = 0;
  for (var i = 0; i < 7; i++) {
    somme += int.parse(sept[i]) * (i.isEven ? 3 : 1);
  }
  return (10 - somme % 10) % 10;
}

/// Vrai pour exactement 8 chiffres dont la clé de contrôle est correcte.
bool estEan8(String? code) =>
    code != null &&
    RegExp(r'^\d{8}$').hasMatch(code) &&
    cleEan8(code.substring(0, 7)) == int.parse(code[7]);

/// Les 67 modules d'un EAN-8 valide, ou null.
String? modulesEan8(String? code) {
  if (!estEan8(code)) return null;
  final gauche = StringBuffer();
  final droite = StringBuffer();
  for (var i = 0; i < 4; i++) {
    gauche.write(_jeuL[int.parse(code![i])]);
  }
  for (var i = 4; i < 8; i++) {
    droite.write(_jeuR[int.parse(code![i])]);
  }
  return '$_garde$gauche$_centre$droite$_garde';
}

// --- Code 128 ---------------------------------------------------------------------------------------------------

/// Plus longue chaîne dessinée en Code 128 : au-delà, le symbole serait trop large pour être lisible.
const maxCaracteresCode128 = 32;

/// Les 107 symboles (valeurs 0 à 106 ; 103 à 105 = départs A, B, C ; 106 = arrêt) : largeurs alternées barre / espace.
const motifsCode128 = [
  '212222', '222122', '222221', '121223', '121322', '131222', '122213', //
  '122312', '132212', '221213', '221312', '231212', '112232', '122132',
  '122231', '113222', '123122', '123221', '223211', '221132', '221231',
  '213212', '223112', '312131', '311222', '321122', '321221', '312212',
  '322112', '322211', '212123', '212321', '232121', '111323', '131123',
  '131321', '112313', '132113', '132311', '211313', '231113', '231311',
  '112133', '112331', '132131', '113123', '113321', '133121', '313121',
  '211331', '231131', '213113', '213311', '213131', '311123', '311321',
  '331121', '312113', '312311', '332111', '314111', '221411', '431111',
  '111224', '111422', '121124', '121421', '141122', '141221', '112214',
  '112412', '122114', '122411', '142112', '142211', '241211', '221114',
  '413111', '241112', '134111', '111242', '121142', '121241', '114212',
  '124112', '124211', '411212', '421112', '421211', '212141', '214121',
  '412121', '111143', '111341', '131141', '114113', '114311', '411113',
  '411311', '113141', '114131', '311141', '411131', '211412', '211214',
  '211232', '2331112',
];

const _departB = 104;
const _departC = 105;
const _arret = 106;
const _basculeA = 101;

String _modulesDuMotif(String motif) {
  var noir = true;
  final modules = StringBuffer();
  for (final largeur in motif.split('')) {
    modules.write((noir ? '1' : '0') * int.parse(largeur));
    noir = !noir;
  }
  return modules.toString();
}

int _valeurB(String caractere) => caractere.codeUnitAt(0) - 32;

/// Valeurs des symboles de données (départ compris), ou null si la chaîne est vide, trop longue ou hors ASCII
/// imprimable. Chiffres seuls : jeu C (paires) ; nombre impair : C puis bascule en A pour le dernier chiffre.
List<int>? valeursCode128(String? texte) {
  if (texte == null || texte.isEmpty || texte.length > maxCaracteresCode128) {
    return null;
  }
  for (final c in texte.codeUnits) {
    if (c < 32 || c > 126) return null;
  }
  if (RegExp(r'^\d+$').hasMatch(texte)) {
    List<int> paires(String chiffres) => [
      for (var i = 0; i < chiffres.length; i += 2)
        int.parse(chiffres.substring(i, i + 2)),
    ];
    if (texte.length.isEven) return [_departC, ...paires(texte)];
    if (texte.length == 1) return [_departB, _valeurB(texte)];
    return [
      _departC,
      ...paires(texte.substring(0, texte.length - 1)),
      _basculeA,
      _valeurB(texte[texte.length - 1]),
    ];
  }
  return [_departB, for (final c in texte.split('')) _valeurB(c)];
}

/// Clé de contrôle : (départ + somme de position × valeur) modulo 103.
int cleCode128(List<int> valeurs) {
  var somme = valeurs[0];
  for (var i = 1; i < valeurs.length; i++) {
    somme += i * valeurs[i];
  }
  return somme % 103;
}

/// Modules d'un symbole Code 128 complet (données, clé, arrêt), ou null si la chaîne n'est pas encodable.
String? modulesCode128(String? texte) {
  final valeurs = valeursCode128(texte);
  if (valeurs == null) return null;
  final symboles = [...valeurs, cleCode128(valeurs), _arret];
  return symboles.map((v) => _modulesDuMotif(motifsCode128[v])).join();
}

// --- Choix du symbole --------------------------------------------------------------------------------------------

enum TypeCodeBarres {
  ean13('EAN-13'),
  ean8('EAN-8'),
  code128('Code 128');

  const TypeCodeBarres(this.libelle);
  final String libelle;
}

/// Symbole à dessiner pour un gencode.
class SymboleCodeBarres {
  const SymboleCodeBarres(this.type, this.modules, this.texte);

  final TypeCodeBarres type;

  /// Modules sans zones de silence (« 1 » = barre, « 0 » = espace).
  final String modules;

  /// Caractères imprimés sous les barres (13 chiffres pour l'EAN-13, 8 pour l'EAN-8, la chaîne pour le Code 128).
  final String texte;
}

/// Choix du symbole : EAN-13 valide, UPC-A valide (dessiné comme l'EAN-13 qui commence par 0), EAN-8 valide, sinon
/// Code 128. Null si la valeur est vide, trop longue ou non imprimable.
SymboleCodeBarres? symboleCodeBarres(String? gencode) {
  final code = gencode?.trim();
  if (code == null || code.isEmpty) return null;
  if (estEan13(code)) {
    return SymboleCodeBarres(TypeCodeBarres.ean13, modulesEan13(code)!, code);
  }
  if (RegExp(r'^\d{12}$').hasMatch(code) && estEan13('0$code')) {
    return SymboleCodeBarres(
      TypeCodeBarres.ean13,
      modulesEan13('0$code')!,
      '0$code',
    );
  }
  if (estEan8(code)) {
    return SymboleCodeBarres(TypeCodeBarres.ean8, modulesEan8(code)!, code);
  }
  final modules = modulesCode128(code);
  return modules == null
      ? null
      : SymboleCodeBarres(TypeCodeBarres.code128, modules, code);
}
