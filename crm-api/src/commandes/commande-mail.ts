/** Corps du mail de validation d'une commande mobile (texte + HTML échappé). Fonctions pures. */

export interface CommandePourMail {
  idCommandeApk: string;
  dateCommande: Date;
  commentaire: string | null;
  nePasLivrerAvant?: Date | null;
  motifNePasLivrerAvant?: string | null;
  promoteur: { displayName: string };
  client: { enseigne: string | null; ville: string | null; codeAs400: string | null };
  lignes: {
    quantite: number;
    prixIndicatif: unknown;
    article: { codeAs400: string | null; libelle: string | null };
  }[];
}

export function echapperHtml(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

const euro = new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR' });
const dateFr = new Intl.DateTimeFormat('fr-FR', { dateStyle: 'long', timeZone: 'Europe/Paris' });

export function construireMailCommande(c: CommandePourMail): { subject: string; html: string; text: string } {
  const magasin = [c.client.enseigne, c.client.ville].filter(Boolean).join(' — ') || 'Magasin';
  const date = dateFr.format(c.dateCommande);
  const lignes = c.lignes.map((l) => {
    const prix = l.prixIndicatif === null || l.prixIndicatif === undefined ? null : Number(l.prixIndicatif);
    return {
      code: l.article.codeAs400 ?? '',
      libelle: l.article.libelle ?? '',
      quantite: l.quantite,
      prix,
    };
  });
  const total = c.lignes.reduce((s, l) => s + l.quantite * Number(l.prixIndicatif ?? 0), 0);
  const commentaire = c.commentaire?.trim() || null;
  // Colonne DATE : le jour est celui de l'UTC (pas de décalage de fuseau).
  const jourLivraison = c.nePasLivrerAvant
    ? c.nePasLivrerAvant.toISOString().slice(0, 10).split('-').reverse().join('/')
    : null;
  const nePasLivrer = jourLivraison
    ? `Ne pas livrer avant le ${jourLivraison}${c.motifNePasLivrerAvant ? ` — ${c.motifNePasLivrerAvant}` : ''}`
    : null;

  const text = [
    `Commande à valider — ${magasin}`,
    `Promoteur : ${c.promoteur.displayName}`,
    `Magasin : ${magasin}${c.client.codeAs400 ? ` (${c.client.codeAs400})` : ''}`,
    `Date : ${date}`,
    '',
    ...lignes.map((l) => `- ${l.code} ${l.libelle} : ${l.quantite}${l.prix !== null ? ` x ${euro.format(l.prix)}` : ''}`),
    '',
    `Total indicatif : ${euro.format(total)} (hors taxes éventuelles, la facturation reste établie par l'ERP)`,
    ...(nePasLivrer ? ['', nePasLivrer] : []),
    ...(commentaire ? ['', `Commentaire : ${commentaire}`] : []),
    '',
    'Merci de répondre à ce mail pour confirmer la commande ou demander une modification.',
  ].join('\n');

  const e = echapperHtml;
  const lignesHtml = lignes
    .map(
      (l) =>
        `<tr><td>${e(l.code)}</td><td>${e(l.libelle)}</td><td style="text-align:right">${l.quantite}</td>` +
        `<td style="text-align:right">${l.prix !== null ? e(euro.format(l.prix)) : ''}</td></tr>`,
    )
    .join('');
  const html =
    `<p>Bonjour,</p>` +
    `<p>Voici la commande préparée par <strong>${e(c.promoteur.displayName)}</strong> pour <strong>${e(magasin)}</strong>` +
    `${c.client.codeAs400 ? ` (${e(c.client.codeAs400)})` : ''}, en date du ${e(date)}.</p>` +
    `<table cellpadding="6" cellspacing="0" border="1" style="border-collapse:collapse">` +
    `<thead><tr><th>Code</th><th>Libellé</th><th>Quantité</th><th>Prix indicatif</th></tr></thead>` +
    `<tbody>${lignesHtml}</tbody></table>` +
    `<p>Total indicatif : <strong>${e(euro.format(total))}</strong> ` +
    `<em>(la facturation reste établie par l'ERP)</em></p>` +
    (nePasLivrer ? `<p><strong>${e(nePasLivrer)}</strong></p>` : '') +
    (commentaire ? `<p>Commentaire : ${e(commentaire).replace(/\r?\n/g, '<br>')}</p>` : '') +
    `<p>Merci de répondre à ce mail pour confirmer la commande ou demander une modification.</p>`;

  return { subject: `Commande à valider — ${magasin} — ${date}`, html, text };
}
