const EUR = new Intl.NumberFormat('fr-FR', {
  style: 'currency',
  currency: 'EUR',
  maximumFractionDigits: 0,
});

const NUM = new Intl.NumberFormat('fr-FR');

/** Formate un montant en euros (arrondi à l'unité) : "119 894 €". */
export function formatEUR(value: string | number): string {
  const n = typeof value === 'string' ? Number(value) : value;
  return Number.isFinite(n) ? EUR.format(n) : '—';
}

/** Formate un entier façon FR : "6 439". */
export function formatNumber(value: number): string {
  return Number.isFinite(value) ? NUM.format(value) : '—';
}
