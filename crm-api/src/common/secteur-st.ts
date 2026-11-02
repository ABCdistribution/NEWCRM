import { PrismaService } from '../prisma/prisma.service';
import { REGIONS_FR } from './regions.util';
import { SecteurRef, trouverSecteur } from './secteur-match.util';

/** Les secteurs de référence : une valeur de `st` = un secteur (code et nom = ceux de la région du même nom). */
const SECTEURS_ST: SecteurRef[] = [
  ...new Map(Object.values(REGIONS_FR).map((r) => [r.code, { id: r.code, code: r.code, nom: r.nom }])).values(),
];

/** Secteur de référence correspondant à un libellé `st` (faute de frappe tolérée), ou null (hors périmètre, ambigu). */
export function secteurReferenceDepuisSt(label: string | null | undefined): SecteurRef | null {
  return trouverSecteur(label, SECTEURS_ST);
}

const estP2002 = (err: unknown) => (err as { code?: string })?.code === 'P2002';

/**
 * Secteur d'un compte d'après l'attribut AD `st` : un secteur = une valeur de `st`.
 *  1. un secteur déjà en base qui correspond (nom ou code, faute de frappe tolérée) est réutilisé ;
 *  2. sinon, si `st` correspond à un secteur de référence (Sud-Est, Nord-Est, Nord-Ouest, Sud-Ouest, Île-de-France,
 *     Corse), il est créé (rattaché à la région du même code) et ajouté à `connus` ;
 *  3. libellé vide, étranger (Piemonte, Belgique…) ou ambigu → null : le compte est signalé, rien n'est inventé.
 * `connus` est la liste des secteurs en base ; elle est complétée au fil des créations.
 */
export async function secteurDepuisSt(
  prisma: PrismaService,
  label: string | null | undefined,
  connus: SecteurRef[],
): Promise<SecteurRef | null> {
  const existant = trouverSecteur(label, connus);
  if (existant) return existant;

  const ref = secteurReferenceDepuisSt(label);
  if (!ref) return null;

  // Le code peut déjà exister sous un nom que le rapprochement n'a pas reconnu : on le réutilise tel quel.
  const parCode = connus.find((s) => s.code === ref.code);
  if (parCode) return parCode;

  const region = await prisma.region.upsert({ where: { code: ref.code }, update: {}, create: { code: ref.code, nom: ref.nom } });
  const creer = () =>
    prisma.secteur.upsert({
      where: { code: ref.code },
      update: {},
      create: { code: ref.code, nom: ref.nom, regionId: region.id },
      select: { id: true, code: true, nom: true },
    });
  let secteur: SecteurRef;
  try {
    secteur = await creer();
  } catch (err) {
    if (!estP2002(err)) throw err;
    secteur = await creer(); // création simultanée par une autre connexion : on relit
  }
  connus.push(secteur);
  return secteur;
}
