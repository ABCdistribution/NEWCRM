/**
 * Régions de France métropolitaine, rattachées à partir du code postal (2 premiers chiffres =
 * département). `ville` + `lat`/`lng` = chef-lieu, utilisé pour placer la région sur une carte.
 */
export interface RegionFr {
  code: string;
  nom: string;
  ville: string;
  lat: number;
  lng: number;
  depts: string[];
}

export const REGIONS_FR: RegionFr[] = [
  { code: 'IDF', nom: 'Île-de-France', ville: 'Paris', lat: 48.8566, lng: 2.3522, depts: ['75', '77', '78', '91', '92', '93', '94', '95'] },
  { code: 'HDF', nom: 'Hauts-de-France', ville: 'Lille', lat: 50.6292, lng: 3.0573, depts: ['02', '59', '60', '62', '80'] },
  { code: 'NOR', nom: 'Normandie', ville: 'Rouen', lat: 49.4432, lng: 1.0993, depts: ['14', '27', '50', '61', '76'] },
  { code: 'BRE', nom: 'Bretagne', ville: 'Rennes', lat: 48.1173, lng: -1.6778, depts: ['22', '29', '35', '56'] },
  { code: 'PDL', nom: 'Pays de la Loire', ville: 'Nantes', lat: 47.2184, lng: -1.5536, depts: ['44', '49', '53', '72', '85'] },
  { code: 'CVL', nom: 'Centre-Val de Loire', ville: 'Orléans', lat: 47.9029, lng: 1.9093, depts: ['18', '28', '36', '37', '41', '45'] },
  { code: 'BFC', nom: 'Bourgogne-Franche-Comté', ville: 'Dijon', lat: 47.322, lng: 5.0415, depts: ['21', '25', '39', '58', '70', '71', '89', '90'] },
  { code: 'GES', nom: 'Grand Est', ville: 'Strasbourg', lat: 48.5734, lng: 7.7521, depts: ['08', '10', '51', '52', '54', '55', '57', '67', '68', '88'] },
  { code: 'NAQ', nom: 'Nouvelle-Aquitaine', ville: 'Bordeaux', lat: 44.8378, lng: -0.5792, depts: ['16', '17', '19', '23', '24', '33', '40', '47', '64', '79', '86', '87'] },
  { code: 'OCC', nom: 'Occitanie', ville: 'Toulouse', lat: 43.6047, lng: 1.4442, depts: ['09', '11', '12', '30', '31', '32', '34', '46', '48', '65', '66', '81', '82'] },
  { code: 'ARA', nom: 'Auvergne-Rhône-Alpes', ville: 'Lyon', lat: 45.764, lng: 4.8357, depts: ['01', '03', '07', '15', '26', '38', '42', '43', '63', '69', '73', '74'] },
  { code: 'PAC', nom: "Provence-Alpes-Côte d'Azur", ville: 'Marseille', lat: 43.2965, lng: 5.3698, depts: ['04', '05', '06', '13', '83', '84'] },
  { code: 'COR', nom: 'Corse', ville: 'Ajaccio', lat: 41.9192, lng: 8.7386, depts: ['20'] },
];

const PAR_DEPT = new Map(REGIONS_FR.flatMap((r) => r.depts.map((d) => [d, r] as const)));

/** Région d'après les 2 premiers chiffres d'un code postal (null si inconnu ou hors métropole). */
export function regionFromDept(dept: string | null | undefined): RegionFr | null {
  return PAR_DEPT.get((dept ?? '').trim().slice(0, 2)) ?? null;
}
