import 'package:crm_app/core/logic/code_barres.dart';
import 'package:flutter_test/flutter_test.dart';

/// Valeurs de référence produites par une bibliothèque indépendante (JsBarcode 3.11.6), les mêmes que celles du web.
const _referenceCode128 = <String, String>{
  '12345678':
      '1101001110010110011100100010110001110001011011000010100100011101101100011101011',
  '376123450030':
      '11010011100100011010001100100001011101101110101110110001101100110011011011000110000100101100011101011',
  '12': '1101001110010110011100100110011101100011101011',
  'ABC123':
      '11010010000101000110001000101100010001000110100111001101100111001011001011100100001011001100011101011',
  '5': '1101001000011011100100110011101001100011101011',
  '3666085207383':
      '110100111001011000100010010000110100011001001101110001010011000100100011000101110101111011001011100100100111101100011101011',
  '123': '11010011100101100111001110101111011001011100100001011001100011101011',
};

void main() {
  group('EAN-13', () {
    test('clé de contrôle et validité', () {
      expect(cleEan13('590123412345'), 7);
      expect(cleEan13('366608520738'), 2);
      expect(cleEan13('abc'), isNull);
      for (final ok in ['3666085207382', '5901234123457', '4006381333931']) {
        expect(estEan13(ok), isTrue, reason: ok);
      }
      for (final ko in [
        '3666085207383',
        '366608520738',
        '36660852073821',
        '3666 0852 0738 2',
        '',
      ]) {
        expect(estEan13(ko), isFalse, reason: ko);
      }
      expect(estEan13(null), isFalse);
    });

    test('symboles conformes à la norme (valeurs écrites à la main)', () {
      expect(
        modulesEan13('5901234123457'),
        '101'
        '0001011'
        '0100111'
        '0110011'
        '0010011'
        '0111101'
        '0011101'
        '01010'
        '1100110'
        '1101100'
        '1000010'
        '1011100'
        '1001110'
        '1000100'
        '101',
      );
      expect(
        modulesEan13('3666085207382'),
        '101'
        '0101111'
        '0101111'
        '0000101'
        '0100111'
        '0001001'
        '0110001'
        '01010'
        '1101100'
        '1110010'
        '1000100'
        '1000010'
        '1001000'
        '1101100'
        '101',
      );
      expect(modulesEan13('3666085207382'), hasLength(95));
      expect(modulesEan13('3666085207383'), isNull);
    });
  });

  group('EAN-8', () {
    test('96385074 : identique à la bibliothèque de référence', () {
      expect(
        modulesEan8('96385074'),
        '1010001011010111101111010110111010101001110111001010001001011100101',
      );
      expect(modulesEan8('96385074'), hasLength(67));
      expect(modulesEan8('96385075'), isNull);
      expect(estEan8('55123457'), isTrue);
    });
  });

  group('Code 128', () {
    test(
      'motifs : 107 symboles de 11 modules (arrêt : 13), tous différents',
      () {
        expect(motifsCode128, hasLength(107));
        for (var v = 0; v < 107; v++) {
          final somme = motifsCode128[v]
              .split('')
              .fold<int>(0, (n, c) => n + int.parse(c));
          expect(somme, v == 106 ? 13 : 11, reason: 'symbole $v');
        }
        expect(motifsCode128.toSet(), hasLength(107));
      },
    );

    test('identique à la bibliothèque de référence', () {
      _referenceCode128.forEach((texte, modules) {
        expect(modulesCode128(texte), modules, reason: texte);
      });
    });

    test('jeux C et A, clé de contrôle calculée à la main', () {
      expect(valeursCode128('1234'), [105, 12, 34]);
      expect(valeursCode128('123'), [105, 12, 101, 19]);
      expect(cleCode128([105, 12, 34, 56, 78]), 47);
    });

    test('valeurs non encodables : pas de symbole', () {
      for (final v in ['', 'été', '12\n34', 'A' * 33]) {
        expect(modulesCode128(v), isNull, reason: v);
      }
      expect(modulesCode128(null), isNull);
    });
  });

  group('choix du symbole', () {
    test('EAN-13 valide', () {
      final s = symboleCodeBarres('3666085207382')!;
      expect(s.type, TypeCodeBarres.ean13);
      expect(s.texte, '3666085207382');
    });

    test('UPC-A valide : EAN-13 avec un 0 devant', () {
      final s = symboleCodeBarres('036000291452')!;
      expect(s.type, TypeCodeBarres.ean13);
      expect(s.texte, '0036000291452');
      expect(
        s.modules,
        '10100011010111101010111100011010001101000110101010110110011101001100110101110010011101101100101',
      );
    });

    test('EAN-8 valide', () {
      expect(symboleCodeBarres('96385074')!.type, TypeCodeBarres.ean8);
    });

    test('tout autre numéro : Code 128 du numéro exact', () {
      for (final v in ['376123450031', '3666085207383', 'ABC123']) {
        final s = symboleCodeBarres(v)!;
        expect(s.type, TypeCodeBarres.code128, reason: v);
        expect(s.texte, v);
        expect(s.modules, modulesCode128(v));
      }
    });

    test('vide ou non imprimable : rien', () {
      for (final v in [null, '', '   ', 'é', 'A' * 33]) {
        expect(symboleCodeBarres(v), isNull, reason: '$v');
      }
    });
  });
}
