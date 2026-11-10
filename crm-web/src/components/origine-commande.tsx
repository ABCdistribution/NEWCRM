import Link from 'next/link';

/**
 * Origine d'une commande : « Appli » (saisie sur mobile) ou « EDI » (échange de données informatisé).
 *
 * RÈGLE PROVISOIRE (seul endroit à modifier) : l'API ne porte pas encore de vrai champ d'origine.
 * L'API renvoie `viaMobile` : true = saisie sur mobile = Appli, false = EDI.
 * Quand un vrai champ existera, ne changer que `origineDe` ci-dessous.
 * Le filtre `?origine=edi|appli` est transmis tel quel à `GET /commandes`.
 * Repris des anciens fronts (supprimés), où ce fichier était identique.
 */
export type Origine = 'edi' | 'appli';

export const ORIGINES: { value: Origine; label: string }[] = [
  { value: 'appli', label: 'Appli' },
  { value: 'edi', label: 'EDI' },
];

/** Valide le paramètre d'URL `origine` (undefined si absent ou invalide). */
export function parseOrigine(v?: string): Origine | undefined {
  return v === 'edi' || v === 'appli' ? v : undefined;
}

/** Origine d'une commande ; undefined si `viaMobile` n'est pas renvoyé par l'API. */
export function origineDe(c: { viaMobile?: boolean }): Origine | undefined {
  if (typeof c.viaMobile !== 'boolean') return undefined;
  return c.viaMobile ? 'appli' : 'edi';
}

/** Pastille « EDI » / « Appli » ; ne rend rien si l'origine est inconnue. */
export function OrigineBadge({ commande }: { commande: { viaMobile?: boolean } }) {
  const o = origineDe(commande);
  if (!o) return null;
  return o === 'edi' ? (
    <span className="rounded-full bg-amber-500/10 px-2 py-0.5 text-xs font-medium text-amber-700 dark:text-amber-400">
      EDI
    </span>
  ) : (
    <span className="rounded-full bg-brand/10 px-2 py-0.5 text-xs font-medium text-brand dark:bg-accent/10 dark:text-accent">
      Appli
    </span>
  );
}

/** Filtre « Toutes / Appli / EDI » piloté par l'URL ; `href` construit l'URL pour une origine donnée. */
export function OrigineFilter({
  actuelle,
  href,
}: {
  actuelle?: Origine;
  href: (origine?: Origine) => string;
}) {
  const base =
    'rounded-full border px-3 py-1 text-xs font-medium transition focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand dark:focus-visible:outline-accent';
  const on = 'border-brand bg-brand text-white dark:border-accent dark:bg-accent dark:text-brand';
  const off =
    'border-neutral-200 text-neutral-600 hover:bg-neutral-100 dark:border-navy-700 dark:text-neutral-300 dark:hover:bg-navy-800';
  return (
    <nav aria-label="Filtrer par origine" className="flex flex-wrap items-center gap-1.5">
      <span className="mr-1 text-[11px] font-semibold uppercase tracking-wider text-neutral-400">Origine</span>
      <Link href={href()} aria-current={actuelle === undefined ? 'true' : undefined} className={`${base} ${actuelle === undefined ? on : off}`}>
        Toutes
      </Link>
      {ORIGINES.map((o) => (
        <Link
          key={o.value}
          href={href(o.value)}
          aria-current={actuelle === o.value ? 'true' : undefined}
          className={`${base} ${actuelle === o.value ? on : off}`}
        >
          {o.label}
        </Link>
      ))}
    </nav>
  );
}
