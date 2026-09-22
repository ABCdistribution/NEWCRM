'use client';

import { useMemo, useState } from 'react';
import { ArrowDown, ArrowUp, ArrowUpDown, Download, Filter, RotateCcw, Search } from 'lucide-react';
import { RappelDetail } from './rappel-detail';

/** Bordereau de retour de produits rappelés, saisi en magasin par le promoteur. */
export type Bordereau = {
  numero: string;
  lignes: number;
  dateRetour: string; // ISO
  promoteur: string;
  codeMagasin: string;
  magasin: string;
};

// Jeu de données représentatif (prototype — à brancher sur le flux de rappels Minos).
const BORDEREAUX: Bordereau[] = [
  { numero: 'RAPPEL_71_01179', lignes: 110, dateRetour: '2026-09-14T15:51:50', promoteur: 'Patricia GIN', codeMagasin: '007642', magasin: 'AUCHAN SM 76 CANTELEU' },
  { numero: 'RAPPEL_21_01178', lignes: 110, dateRetour: '2026-09-14T13:48:37', promoteur: 'Sophie ROBERT', codeMagasin: '003025', magasin: 'LECLERC 10 ST PARRES AUX TERT.' },
  { numero: 'RAPPEL_27_01177', lignes: 110, dateRetour: '2026-09-11T13:18:10', promoteur: 'Sophie HERBIN', codeMagasin: '003477', magasin: 'LECLERC 25 HOUTAUD' },
  { numero: 'RAPPEL_135_01176', lignes: 108, dateRetour: '2026-09-10T18:43:18', promoteur: 'Grégory DOZINEL', codeMagasin: '098121', magasin: 'SHOPPING CENTER MASSEN' },
  { numero: 'RAPPEL_23_01175', lignes: 110, dateRetour: '2026-09-09T15:45:40', promoteur: 'Julien HOLIN', codeMagasin: '003096', magasin: 'LECLERC 51 PIERRY' },
  { numero: 'RAPPEL_135_01174', lignes: 108, dateRetour: '2026-09-04T08:57:36', promoteur: 'Grégory DOZINEL', codeMagasin: '091350', magasin: 'ITM GOSSELIES' },
  { numero: 'RAPPEL_198_01173', lignes: 107, dateRetour: '2026-09-03T18:14:34', promoteur: 'Mélanie TISSERANDOT', codeMagasin: '004084', magasin: 'SUPER U 39 TAVAUX' },
  { numero: 'RAPPEL_98_01172', lignes: 108, dateRetour: '2026-08-26T07:31:21', promoteur: 'Fabrice QUEVAL', codeMagasin: '003656', magasin: 'LECLERC 59 DOUAI' },
  { numero: 'RAPPEL_140_01171', lignes: 107, dateRetour: '2026-08-24T19:09:14', promoteur: 'Laurent BRILLON', codeMagasin: '003393', magasin: 'LECLERC 62 LUMBRES' },
  { numero: 'RAPPEL_23_01170', lignes: 107, dateRetour: '2026-08-21T14:49:33', promoteur: 'Julien HOLIN', codeMagasin: '003024', magasin: 'LECLERC 51 VITRY EN PERTHOIS' },
  { numero: 'RAPPEL_203_01169', lignes: 110, dateRetour: '2026-08-18T17:45:37', promoteur: 'Marie LEOCADIE', codeMagasin: '004240', magasin: 'SUPER U 13 ST MARTIN DE CRAU' },
  { numero: 'RAPPEL_71_01168', lignes: 106, dateRetour: '2026-08-17T09:22:05', promoteur: 'Patricia GIN', codeMagasin: '007731', magasin: 'CARREFOUR MARKET 76 YVETOT' },
  { numero: 'RAPPEL_98_01167', lignes: 105, dateRetour: '2026-08-12T16:03:48', promoteur: 'Fabrice QUEVAL', codeMagasin: '003702', magasin: 'AUCHAN 59 ENGLOS' },
  { numero: 'RAPPEL_140_01166', lignes: 107, dateRetour: '2026-08-07T11:37:29', promoteur: 'Laurent BRILLON', codeMagasin: '003410', magasin: 'INTERMARCHE 62 BETHUNE' },
  { numero: 'RAPPEL_198_01165', lignes: 104, dateRetour: '2026-08-03T10:12:11', promoteur: 'Mélanie TISSERANDOT', codeMagasin: '004120', magasin: 'LECLERC 39 LONS LE SAUNIER' },
];

const DATE_FMT = new Intl.DateTimeFormat('fr-FR', {
  year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit',
});

type SortKey = 'numero' | 'lignes' | 'dateRetour' | 'promoteur' | 'codeMagasin' | 'magasin';

const COLONNES: { key: SortKey; label: string; align?: 'right' }[] = [
  { key: 'numero', label: 'N° bordereau' },
  { key: 'lignes', label: 'Lignes', align: 'right' },
  { key: 'dateRetour', label: 'Date retour' },
  { key: 'promoteur', label: 'Promoteur' },
  { key: 'codeMagasin', label: 'Code magasin' },
  { key: 'magasin', label: 'Libellé magasin' },
];

/** Tableau des bordereaux de retour (rappels produits) avec filtres, tri et export. */
export function RappelsBoard() {
  const [magasin, setMagasin] = useState('');
  const [promoteur, setPromoteur] = useState('');
  const [q, setQ] = useState('');
  const [sort, setSort] = useState<{ key: SortKey; dir: 1 | -1 }>({ key: 'dateRetour', dir: -1 });
  const [taille, setTaille] = useState(25);
  const [detail, setDetail] = useState<Bordereau | null>(null);

  const magasins = useMemo(() => [...new Set(BORDEREAUX.map((b) => b.magasin))].sort(), []);
  const promoteurs = useMemo(() => [...new Set(BORDEREAUX.map((b) => b.promoteur))].sort(), []);

  const filtres = useMemo(() => {
    const query = q.trim().toLowerCase();
    const rows = BORDEREAUX.filter(
      (b) =>
        (magasin === '' || b.magasin === magasin) &&
        (promoteur === '' || b.promoteur === promoteur) &&
        (query === '' ||
          [b.numero, b.promoteur, b.codeMagasin, b.magasin].some((v) => v.toLowerCase().includes(query))),
    );
    return rows.sort((a, b) => {
      const va = a[sort.key];
      const vb = b[sort.key];
      const cmp = typeof va === 'number' && typeof vb === 'number' ? va - vb : String(va).localeCompare(String(vb));
      return cmp * sort.dir;
    });
  }, [magasin, promoteur, q, sort]);

  const visibles = filtres.slice(0, taille);

  const trier = (key: SortKey) =>
    setSort((s) => (s.key === key ? { key, dir: s.dir === 1 ? -1 : 1 } : { key, dir: key === 'dateRetour' ? -1 : 1 }));

  const exportCsv = () => {
    const header = ['N° bordereau', 'Lignes', 'Date retour', 'Promoteur', 'Code magasin', 'Libellé magasin'];
    const lines = filtres.map((b) => [b.numero, String(b.lignes), DATE_FMT.format(new Date(b.dateRetour)), b.promoteur, b.codeMagasin, b.magasin]);
    const csv = [header, ...lines].map((r) => r.map((c) => `"${c.replace(/"/g, '""')}"`).join(';')).join('\n');
    const blob = new Blob(['﻿' + csv], { type: 'text/csv;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = 'rappels-bordereaux.csv';
    link.click();
    URL.revokeObjectURL(url);
  };

  const selectCls =
    'rounded-lg border border-neutral-200 bg-white px-2.5 py-1.5 text-xs outline-none transition focus:border-brand dark:border-navy-700 dark:bg-navy-950 dark:focus:border-accent';

  if (detail) {
    return <RappelDetail bordereau={detail} onRetour={() => setDetail(null)} />;
  }

  return (
    <div className="flex min-w-0 flex-col gap-3">
      {/* Filtres */}
      <div className="flex flex-wrap items-end gap-2 rounded-2xl bg-white p-3 shadow-card">
        <label className="flex flex-col gap-1 text-[11px] font-semibold uppercase tracking-wider text-neutral-400">
          Magasin
          <select value={magasin} onChange={(e) => setMagasin(e.target.value)} className={selectCls}>
            <option value="">Tous les magasins</option>
            {magasins.map((m) => (
              <option key={m} value={m}>{m}</option>
            ))}
          </select>
        </label>
        <label className="flex flex-col gap-1 text-[11px] font-semibold uppercase tracking-wider text-neutral-400">
          Promoteur
          <select value={promoteur} onChange={(e) => setPromoteur(e.target.value)} className={selectCls}>
            <option value="">Tous les promoteurs</option>
            {promoteurs.map((p) => (
              <option key={p} value={p}>{p}</option>
            ))}
          </select>
        </label>
        {magasin || promoteur || q ? (
          <button
            type="button"
            onClick={() => { setMagasin(''); setPromoteur(''); setQ(''); }}
            className="inline-flex items-center gap-1.5 rounded-lg border border-neutral-200 px-3 py-1.5 text-xs font-medium text-neutral-600 transition hover:bg-neutral-100 dark:border-navy-700 dark:text-neutral-300 dark:hover:bg-navy-800"
          >
            <RotateCcw size={12} /> Réinitialiser
          </button>
        ) : null}
        <div className="ml-auto flex items-center gap-2">
          <div className="flex items-center gap-1.5 rounded-lg border border-neutral-200 px-2.5 py-1.5 dark:border-navy-700">
            <Search size={13} className="shrink-0 text-neutral-400" />
            <input
              value={q}
              onChange={(e) => setQ(e.target.value)}
              placeholder="Bordereau, magasin, promoteur…"
              className="w-44 bg-transparent text-xs outline-none placeholder:text-neutral-400"
            />
          </div>
          <button
            type="button"
            onClick={exportCsv}
            className="inline-flex items-center gap-1.5 rounded-lg bg-emerald-600 px-3 py-1.5 text-xs font-semibold text-white transition hover:bg-emerald-700"
          >
            <Download size={13} /> Export CSV
          </button>
        </div>
      </div>

      {/* Tableau */}
      <div className="overflow-x-auto rounded-2xl bg-white shadow-card">
        <table className="w-full min-w-[760px] text-sm">
          <thead className="border-b border-neutral-100 text-left text-[11px] uppercase tracking-wider text-neutral-400 dark:border-navy-700">
            <tr>
              {COLONNES.map((c) => (
                <th key={c.key} className={`px-4 py-2.5 font-medium ${c.align === 'right' ? 'text-right' : ''}`}>
                  <button
                    type="button"
                    onClick={() => trier(c.key)}
                    className="inline-flex items-center gap-1 uppercase tracking-wider transition hover:text-brand dark:hover:text-accent"
                  >
                    {c.label}
                    {sort.key === c.key ? (
                      sort.dir === 1 ? <ArrowUp size={11} /> : <ArrowDown size={11} />
                    ) : (
                      <ArrowUpDown size={11} className="opacity-40" />
                    )}
                  </button>
                </th>
              ))}
            </tr>
          </thead>
          <tbody className="divide-y divide-neutral-100 dark:divide-navy-700">
            {visibles.map((b) => (
              <tr
                key={b.numero}
                onClick={() => setDetail(b)}
                className="cursor-pointer hover:bg-neutral-50 dark:hover:bg-navy-800/50"
                title={`Ouvrir le bordereau ${b.numero}`}
              >
                <td className="px-4 py-3 font-mono text-xs font-medium text-brand dark:text-accent">{b.numero}</td>
                <td className="px-4 py-3 text-right tabular-nums">{b.lignes}</td>
                <td className="px-4 py-3 text-neutral-600 dark:text-neutral-300">{DATE_FMT.format(new Date(b.dateRetour))}</td>
                <td className="px-4 py-3">{b.promoteur}</td>
                <td className="px-4 py-3 font-mono text-xs text-neutral-500">{b.codeMagasin}</td>
                <td className="px-4 py-3 text-neutral-600 dark:text-neutral-300">{b.magasin}</td>
              </tr>
            ))}
            {visibles.length === 0 ? (
              <tr>
                <td colSpan={6} className="px-4 py-10 text-center text-neutral-400">
                  Aucun bordereau pour ces filtres.
                </td>
              </tr>
            ) : null}
          </tbody>
        </table>
      </div>

      {/* Pied : taille de page + compteur */}
      <div className="flex flex-wrap items-center justify-between gap-2 text-xs text-neutral-500">
        <label className="flex items-center gap-1.5">
          Afficher
          <select value={taille} onChange={(e) => setTaille(Number(e.target.value))} className={selectCls}>
            {[10, 25, 50].map((n) => (
              <option key={n} value={n}>{n}</option>
            ))}
          </select>
          lignes
        </label>
        <span className="inline-flex items-center gap-1">
          <Filter size={11} />
          {visibles.length} affiché{visibles.length > 1 ? 's' : ''} sur {filtres.length} bordereau{filtres.length > 1 ? 'x' : ''}
        </span>
      </div>
    </div>
  );
}
