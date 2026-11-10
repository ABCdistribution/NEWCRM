const EUR = new Intl.NumberFormat('fr-FR', {
  style: 'currency',
  currency: 'EUR',
  maximumFractionDigits: 0,
});

/** Formate un montant en euros (arrondi à l'unité) : "119 894 €". */
export function formatEUR(value: string | number): string {
  const n = typeof value === 'string' ? Number(value) : value;
  return Number.isFinite(n) ? EUR.format(n) : '—';
}
