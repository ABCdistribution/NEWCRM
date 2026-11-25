import { barresDeModules } from '@/lib/barres';
import { GARDES_EAN13, MODULES_EAN13 } from '@/lib/ean13';
import { GARDES_EAN8, MODULES_EAN8 } from '@/lib/ean8';
import { symboleCodeBarres, type SymboleCodeBarres } from '@/lib/code-barres';
import { texteOuTiret } from '@/lib/produit-fiche';

/**
 * Géométrie du dessin, en modules (1 module = 1 unité du viewBox) : barres de 44 de haut, gardes (EAN) plus longues de
 * 8, caractères sous les barres.
 */
const HAUT_MARGE = 2;
const HAUT_BARRES = 44; // barres de 2 à 46
const HAUT_GARDES = 52; // gardes de 2 à 54
const LIGNE_DE_BASE = 53; // caractères entre 47 et 53, sous les barres
const HAUTEUR = HAUT_MARGE + HAUT_GARDES + 2;
const TAILLE_CHIFFRE = 8;

type Dessin = {
  silenceGauche: number;
  silenceDroite: number;
  modules: number;
  gardes: readonly { x: number; largeur: number }[];
  /** Caractères imprimés : x en modules depuis le bord gauche du viewBox. */
  textes: { x: number; c: string }[];
};

/** Zones de silence et position des caractères selon le type de symbole (normes EAN-13, EAN-8 ; 10 modules en Code 128). */
function dessinDe(s: SymboleCodeBarres): Dessin {
  if (s.type === 'EAN-13') {
    const silenceGauche = 11;
    return {
      silenceGauche,
      silenceDroite: 7,
      modules: MODULES_EAN13,
      gardes: GARDES_EAN13,
      textes: Array.from(s.texte, (c, i) => ({
        c,
        // Chiffre 0 : dans la zone de silence de gauche ; 1 à 6 : sous le groupe de gauche ; 7 à 12 : sous celui de droite.
        x: i === 0 ? silenceGauche / 2 : i <= 6 ? silenceGauche + 3 + (i - 1) * 7 + 3.5 : silenceGauche + 50 + (i - 7) * 7 + 3.5,
      })),
    };
  }
  if (s.type === 'EAN-8') {
    const silence = 7;
    return {
      silenceGauche: silence,
      silenceDroite: silence,
      modules: MODULES_EAN8,
      gardes: GARDES_EAN8,
      // Quatre chiffres sous le groupe de gauche (modules 3 à 31), quatre sous celui de droite (36 à 64).
      textes: Array.from(s.texte, (c, i) => ({ c, x: silence + (i < 4 ? 3 + i * 7 : 36 + (i - 4) * 7) + 3.5 })),
    };
  }
  const silence = 10;
  const modules = s.modules.length;
  return {
    silenceGauche: silence,
    silenceDroite: silence,
    modules,
    gardes: [],
    textes: [{ c: s.texte, x: silence + modules / 2 }],
  };
}

/**
 * Code-barres en SVG en ligne (aucune dépendance) : barres noires sur fond blanc, zones de silence, caractères dessous.
 * EAN-13 (et UPC-A, dessiné comme un EAN-13), EAN-8, et Code 128 pour tout autre gencode (clé de contrôle fausse,
 * autre longueur, lettres…) : un code-barres est dessiné dès que la valeur est encodable, et il encode toujours
 * exactement le numéro affiché (jamais un faux EAN). Seule une valeur absente, trop longue ou non imprimable n'est pas
 * dessinée : le numéro (ou « — ») s'affiche seul.
 * Pas de `shape-rendering: crispEdges` : la largeur n'est pas un multiple entier du nombre de modules, et caler chaque
 * barre sur des pixels entiers déformerait les proportions.
 */
export function CodeBarres({ gencode }: { gencode: string | null | undefined }) {
  const symbole = symboleCodeBarres(gencode);
  if (symbole === null) {
    return <p className="font-mono text-sm tabular-nums">{texteOuTiret(gencode)}</p>;
  }

  const d = dessinDe(symbole);
  const largeur = d.silenceGauche + d.modules + d.silenceDroite;
  const estGarde = (x: number, l: number): boolean => d.gardes.some((g) => x >= g.x && x + l <= g.x + g.largeur);
  const ean = symbole.type !== 'Code 128';

  return (
    <svg
      role="img"
      aria-label={`Code-barres ${symbole.type} ${symbole.texte}`}
      viewBox={`0 0 ${largeur} ${HAUTEUR}`}
      className={`h-auto w-full ${ean ? 'max-w-[16rem]' : 'max-w-[18rem]'}`}
    >
      <rect x={0} y={0} width={largeur} height={HAUTEUR} className="fill-white" />
      {barresDeModules(symbole.modules).map(({ x, largeur: l }) => (
        <rect
          key={x}
          x={d.silenceGauche + x}
          y={HAUT_MARGE}
          width={l}
          height={estGarde(x, l) ? HAUT_GARDES : HAUT_BARRES}
          className="fill-black"
        />
      ))}
      {d.textes.map(({ c, x }, i) => (
        <text
          key={i}
          x={x}
          y={LIGNE_DE_BASE}
          fontSize={TAILLE_CHIFFRE}
          textAnchor="middle"
          className="fill-black font-mono"
          aria-hidden="true"
        >
          {c}
        </text>
      ))}
    </svg>
  );
}
