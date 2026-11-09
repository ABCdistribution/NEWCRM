import { describe, expect, it } from 'vitest';
import { adresseMail, lienMailto, lienTel } from './contact-liens';

describe('adresseMail / lienMailto', () => {
  it('accepte une adresse ordinaire et retire les espaces autour', () => {
    expect(adresseMail('  marie.durand@magasin.fr ')).toBe('marie.durand@magasin.fr');
    expect(lienMailto('marie.durand@magasin.fr')).toBe('mailto:marie.durand@magasin.fr');
  });

  it('accepte +, apostrophe et lettres accentuées', () => {
    expect(adresseMail("o'brien+promo@exemple.com")).not.toBeNull();
    expect(adresseMail('élodie@café.fr')).not.toBeNull();
  });

  it.each([
    'a@b.fr?subject=Facture urgente&body=Cliquez http://evil.example',
    'a@b.fr&cc=autre@exemple.com',
    'a@b.fr#fragment',
    'a@b.fr,autre@b.fr',
    'a@b.fr;autre@b.fr',
    'a b@c.fr',
    '<script>@b.fr',
    'javascript:alert(1)',
    'sans-arobase.fr',
    'a@b',
    '',
  ])('refuse %j (pas de lien mailto)', (valeur) => {
    expect(adresseMail(valeur)).toBeNull();
    expect(lienMailto(valeur)).toBeNull();
  });

  it('refuse null, undefined et une adresse démesurée', () => {
    expect(lienMailto(null)).toBeNull();
    expect(lienMailto(undefined)).toBeNull();
    expect(lienMailto(`${'a'.repeat(250)}@b.fr`)).toBeNull();
  });
});

describe('lienTel', () => {
  it('ne garde que les chiffres', () => {
    expect(lienTel('04 72 00 00 00')).toBe('tel:0472000000');
    expect(lienTel('04.72.00-00 (00)')).toBe('tel:0472000000');
  });

  it('conserve un + initial', () => {
    expect(lienTel('+33 4 72 00 00 00')).toBe('tel:+33472000000');
    expect(lienTel('04+72')).toBe('tel:0472');
  });

  it('neutralise les paramètres ajoutés à un numéro', () => {
    expect(lienTel('0472000000;phone-context=evil')).toBe('tel:0472000000');
  });

  it.each([null, undefined, '', 'abc', '12'])('refuse %j', (valeur) => {
    expect(lienTel(valeur)).toBeNull();
  });
});
