'use client';

import { useMemo, useState } from 'react';
import Link from 'next/link';
import { ArrowDown, ArrowUp, Bell, TrendingDown } from 'lucide-react';
import type { ClientEnrichedRow } from '@/lib/api';
import { ClassBadge } from './class-badge';

const EUR = new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR', maximumFractionDigits: 0 });

/**
 * Enseigne (chaîne) détectée dans le nom du magasin / la raison sociale, contre
 * une liste connue. Gère les variantes (Super U → Système U, E.Leclerc → Leclerc…).
 * Renvoie null si aucune enseigne connue ne correspond.
 */
const ENSEIGNES = [
  'Auchan', 'Carrefour', 'Casino', 'Cora', 'Intermarché', 'Leclerc', 'Monoprix',
  'Système U', 'Lidl', 'Aldi', 'Franprix', 'Simply Market', 'Netto', 'Supermarché Match',
  'Colruyt', 'Grand Frais', 'Biocoop', 'Naturalia',
];
function marque(enseigne: string, raisonSociale?: string): string | null {
  const s = `${enseigne} ${raisonSociale ?? ''}`
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, ''); // sans accents
  const has = (re: RegExp) => re.test(s);
  if (has(/\bleclerc\b|e\.?\s?leclerc/)) return 'Leclerc';
  if (has(/intermarche|\bitm\b/)) return 'Intermarché';
  if (has(/systeme u|super u|hyper u|\bu express\b|magasins? u|marche u/)) return 'Système U';
  if (has(/simply/)) return 'Simply Market';
  if (has(/\bmatch\b/)) return 'Supermarché Match';
  for (const e of ENSEIGNES) {
    const key = e.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '');
    if (s.includes(key)) return e;
  }
  return null;
}

function initiales(nom: string): string {
  return nom
    .split(/\s+/)
    .map((s) => s[0])
    .filter(Boolean)
    .slice(0, 2)
    .join('')
    .toUpperCase();
}

// Teintes d'avatar CS, dans la palette selios (marine, lavande, periwinkle, teal).
const CS_TINTS = [
  'bg-brand text-accent',
  'bg-[#7D8CCE] text-white',
  'bg-[#A2B5F4] text-brand',
  'bg-[#0E8F91] text-white',
];
function tint(nom: string): string {
  let h = 0;
  for (let i = 0; i < nom.length; i++) h = (h * 31 + nom.charCodeAt(i)) >>> 0;
  return CS_TINTS[h % CS_TINTS.length];
}

type SortKey = 'magasin' | 'enseigne' | 'ville' | 'ca' | 'delta' | 'visite' | 'classe' | 'alertes';

const chip =
  'rounded-full px-3 py-1 text-xs font-medium transition border';
const chipOff =
  'border-neutral-200 text-neutral-600 hover:bg-neutral-100 dark:border-navy-700 dark:text-neutral-300 dark:hover:bg-navy-800';
const chipOn = 'border-brand bg-brand text-white dark:border-accent dark:bg-accent dark:text-brand';

export function MagasinsTable({ rows }: { rows: ClientEnrichedRow[] }) {
  const [enseigne, setEnseigne] = useState<string | null>(null);
  const [cs, setCs] = useState<string | null>(null);
  const [avecAlertes, setAvecAlertes] = useState(false);
  const [enBaisse, setEnBaisse] = useState(false);
  const [sort, setSort] = useState<{ key: SortKey; dir: 1 | -1 }>({ key: 'magasin', dir: 1 });

  const enseignes = useMemo(
    () =>
      [...new Set(rows.map((r) => marque(r.enseigne, r.raisonSociale)).filter((m): m is string => m !== null))].sort(
        (a, b) => a.localeCompare(b),
      ),
    [rows],
  );
  const commerciaux = useMemo(() => {
    const map = new Map<string, string>();
    for (const r of rows) if (r.cs) map.set(r.cs.displayName, initiales(r.cs.displayName));
    return [...map.entries()].sort((a, b) => a[0].localeCompare(b[0]));
  }, [rows]);

  const visibles = useMemo(() => {
    let out = rows.filter((r) => {
      if (enseigne && marque(r.enseigne, r.raisonSociale) !== enseigne) return false;
      if (cs && r.cs?.displayName !== cs) return false;
      if (avecAlertes && r.alertes === 0) return false;
      if (enBaisse && !r.enBaisse) return false;
      return true;
    });
    const key = sort.key;
    const val = (r: ClientEnrichedRow): string | number => {
      switch (key) {
        case 'magasin': return r.enseigne.toLowerCase();
        case 'enseigne': return (marque(r.enseigne, r.raisonSociale) ?? 'zzz').toLowerCase();
        case 'ville': return (r.ville ?? '').toLowerCase();
        case 'ca': return r.caMois;
        case 'delta': return r.deltaPct ?? -Infinity;
        case 'visite': return r.derniereVisiteJours ?? Infinity;
        case 'classe': return r.niveauClass ?? 'H'; // sans classe : après G
        case 'alertes': return r.alertes;
      }
    };
    out = [...out].sort((a, b) => {
      const va = val(a), vb = val(b);
      if (va < vb) return -1 * sort.dir;
      if (va > vb) return 1 * sort.dir;
      return 0;
    });
    return out;
  }, [rows, enseigne, cs, avecAlertes, enBaisse, sort]);

  const toggleSort = (key: SortKey) =>
    setSort((s) => (s.key === key ? { key, dir: (s.dir * -1) as 1 | -1 } : { key, dir: 1 }));

  return (
    <div className="flex flex-col gap-3">
      {/* Barre de filtres */}
      <div className="flex flex-col gap-2 rounded-2xl bg-white p-3 shadow-card">
        <div className="flex flex-wrap items-center gap-1.5">
          <span className="mr-1 text-[11px] font-semibold uppercase tracking-wider text-neutral-400">Enseigne</span>
          <button className={`${chip} ${enseigne === null ? chipOn : chipOff}`} onClick={() => setEnseigne(null)}>
            Toutes
          </button>
          {enseignes.map((e) => (
            <button key={e} className={`${chip} ${enseigne === e ? chipOn : chipOff}`} onClick={() => setEnseigne(e)}>
              {e}
            </button>
          ))}
          <span className="mx-1 h-4 w-px bg-neutral-200 dark:bg-navy-700" />
          <button
            className={`${chip} inline-flex items-center gap-1 ${avecAlertes ? chipOn : chipOff}`}
            onClick={() => setAvecAlertes((v) => !v)}
          >
            <Bell size={12} /> Avec alertes
          </button>
          <button
            className={`${chip} inline-flex items-center gap-1 ${enBaisse ? chipOn : chipOff}`}
            onClick={() => setEnBaisse((v) => !v)}
          >
            <TrendingDown size={12} /> En baisse
          </button>
        </div>
        {commerciaux.length > 1 ? (
          <div className="flex flex-wrap items-center gap-1.5">
            <span className="mr-1 text-[11px] font-semibold uppercase tracking-wider text-neutral-400">CS</span>
            <button className={`${chip} ${cs === null ? chipOn : chipOff}`} onClick={() => setCs(null)}>
              Tous
            </button>
            {commerciaux.map(([nom, ini]) => (
              <button
                key={nom}
                title={nom}
                className={`${chip} ${cs === nom ? chipOn : chipOff}`}
                onClick={() => setCs(nom)}
              >
                {ini}
              </button>
            ))}
          </div>
        ) : null}
      </div>

      {/* < md : tri compact (les en-têtes cliquables du tableau n'existent pas en vue cartes). */}
      <div className="flex items-center gap-2 md:hidden">
        <label htmlFor="tri-magasins" className="text-[11px] font-semibold uppercase tracking-wider text-neutral-400">
          Tri
        </label>
        <select
          id="tri-magasins"
          value={`${sort.key}:${sort.dir}`}
          onChange={(e) => {
            const [key, dir] = e.target.value.split(':');
            setSort({ key: key as SortKey, dir: Number(dir) as 1 | -1 });
          }}
          className="rounded-lg border border-neutral-200 bg-white px-2 py-1.5 text-xs text-neutral-700 dark:border-navy-700 dark:bg-navy-950 dark:text-neutral-200"
        >
          <option value="magasin:1">Magasin (A→Z)</option>
          <option value="ca:-1">CA mois (haut→bas)</option>
          <option value="delta:1">Δ vs N-1 (pire d’abord)</option>
          <option value="visite:-1">Dern. visite (ancienne d’abord)</option>
          <option value="classe:1">Classe (A d’abord)</option>
          <option value="alertes:-1">Alertes (plus d’abord)</option>
        </select>
      </div>

      {/* < md : cartes magasins. */}
      <ul className="flex flex-col gap-2.5 md:hidden">
        {visibles.map((r) => (
          <li key={r.id} className="relative rounded-2xl bg-white p-4 shadow-card">
            <Link href={`/clients/${r.id}`} className="absolute inset-0" aria-label={`Fiche ${r.enseigne}`} />
            <div className="flex items-start justify-between gap-2">
              <div className="min-w-0">
                <p className="truncate font-medium text-brand dark:text-accent">{r.enseigne}</p>
                <p className="text-[11px] text-neutral-400">
                  <span className="font-mono">{r.codeAs400}</span>
                  {r.ville ? ` · ${r.ville}` : ''}
                </p>
              </div>
              <span className="flex shrink-0 items-center gap-1.5">
                <ClassBadge value={r.niveauClass} />
                {r.alertes > 0 ? (
                  <span className="inline-flex h-5 min-w-5 items-center justify-center rounded-full bg-red-100 px-1 text-xs font-bold text-red-600 dark:bg-red-500/15">
                    {r.alertes}
                  </span>
                ) : null}
              </span>
            </div>
            <div className="mt-3 flex flex-wrap items-center gap-x-4 gap-y-1 text-sm">
              <span className="font-semibold text-brand dark:text-accent">
                {r.caMois > 0 ? EUR.format(r.caMois) : 'CA —'}
              </span>
              {r.deltaPct != null ? (
                <span className={r.deltaPct >= 0 ? 'font-medium text-emerald-600' : 'font-medium text-red-500'}>
                  {r.deltaPct >= 0 ? '+' : ''}{r.deltaPct} %
                </span>
              ) : null}
              {r.derniereVisiteJours == null ? (
                <span className="text-neutral-400">jamais visité</span>
              ) : (
                <span className={r.enRetard ? 'font-medium text-red-500' : 'text-neutral-500'}>
                  visite {r.derniereVisiteJours} j
                </span>
              )}
              {r.cs ? (
                <span className="inline-flex items-center gap-1.5 text-neutral-500">
                  <span className={`flex h-5 w-5 items-center justify-center rounded-full text-[9px] font-bold ${tint(r.cs.displayName)}`}>
                    {initiales(r.cs.displayName)}
                  </span>
                  {r.cs.displayName.split(/\s+/)[0]}
                </span>
              ) : null}
            </div>
          </li>
        ))}
        {visibles.length === 0 ? (
          <li className="rounded-2xl bg-white px-4 py-8 text-center text-sm text-neutral-400 shadow-card">
            Aucun magasin ne correspond à ces filtres.
          </li>
        ) : null}
      </ul>

      {/* ≥ md : tableau. */}
      <div className="hidden overflow-x-auto rounded-2xl bg-white shadow-card md:block">
        <table className="w-full min-w-[900px] text-sm">
          <thead className="border-b border-neutral-100 text-left text-[11px] uppercase tracking-wider text-neutral-400 dark:border-navy-700">
            <tr>
              <Th label="Magasin" k="magasin" sort={sort} onSort={toggleSort} />
              <Th label="Enseigne" k="enseigne" sort={sort} onSort={toggleSort} />
              <Th label="Ville" k="ville" sort={sort} onSort={toggleSort} />
              <th className="px-4 py-2.5 font-medium">CS</th>
              <Th label="CA mois" k="ca" sort={sort} onSort={toggleSort} align="right" />
              <Th label="Δ vs N-1" k="delta" sort={sort} onSort={toggleSort} align="right" />
              <Th label="Dern. visite" k="visite" sort={sort} onSort={toggleSort} />
              <Th label="Classe" k="classe" sort={sort} onSort={toggleSort} align="center" />
              <Th label="Alertes" k="alertes" sort={sort} onSort={toggleSort} align="center" />
            </tr>
          </thead>
          <tbody className="divide-y divide-neutral-100 dark:divide-navy-700">
            {visibles.map((r) => (
              <tr key={r.id} className="relative hover:bg-neutral-50 dark:hover:bg-navy-800/50">
                <td className="px-4 py-3">
                  <Link href={`/clients/${r.id}`} className="absolute inset-0" aria-label={`Fiche ${r.enseigne}`} />
                  <div className="font-medium text-brand dark:text-accent">{r.enseigne}</div>
                  <div className="font-mono text-[11px] text-neutral-400">{r.codeAs400}</div>
                </td>
                <td className="px-4 py-3">
                  {marque(r.enseigne, r.raisonSociale) ? (
                    <span className="rounded-md bg-neutral-100 px-2 py-0.5 text-xs font-medium text-neutral-600 dark:bg-navy-800 dark:text-neutral-300">
                      {marque(r.enseigne, r.raisonSociale)}
                    </span>
                  ) : (
                    <span className="text-neutral-300">—</span>
                  )}
                </td>
                <td className="px-4 py-3">
                  <div>{r.ville ?? '—'}</div>
                  {r.codePostal ? <div className="text-[11px] text-neutral-400">{r.codePostal}</div> : null}
                </td>
                <td className="px-4 py-3">
                  {r.cs ? (
                    <div className="flex items-center gap-2">
                      <span className={`flex h-6 w-6 shrink-0 items-center justify-center rounded-full text-[10px] font-bold ${tint(r.cs.displayName)}`}>
                        {initiales(r.cs.displayName)}
                      </span>
                      <span className="text-neutral-600 dark:text-neutral-300">
                        {r.cs.displayName.split(/\s+/)[0]}
                      </span>
                    </div>
                  ) : (
                    <span className="text-neutral-300">—</span>
                  )}
                </td>
                <td className="whitespace-nowrap px-4 py-3 text-right font-semibold text-brand dark:text-accent">
                  {r.caMois > 0 ? EUR.format(r.caMois) : '—'}
                </td>
                <td className="px-4 py-3 text-right">
                  {r.deltaPct == null ? (
                    <span className="text-neutral-300">—</span>
                  ) : (
                    <span className={r.deltaPct >= 0 ? 'font-medium text-emerald-600' : 'font-medium text-red-500'}>
                      {r.deltaPct >= 0 ? '+' : ''}{r.deltaPct} %
                    </span>
                  )}
                </td>
                <td className="px-4 py-3">
                  {r.derniereVisiteJours == null ? (
                    <span className="text-neutral-300">jamais</span>
                  ) : (
                    <>
                      <div className={r.enRetard ? 'font-medium text-red-500' : 'font-medium text-emerald-600'}>
                        {r.derniereVisiteJours}j
                      </div>
                      {r.periodicite ? <div className="text-[11px] text-neutral-400">{r.periodicite}</div> : null}
                    </>
                  )}
                </td>
                <td className="px-4 py-3 text-center">
                  {r.niveauClass ? <ClassBadge value={r.niveauClass} /> : <span className="text-neutral-300">—</span>}
                </td>
                <td className="px-4 py-3 text-center">
                  {r.alertes > 0 ? (
                    <span className="inline-flex h-5 min-w-5 items-center justify-center rounded-full bg-red-100 px-1 text-xs font-bold text-red-600 dark:bg-red-500/15">
                      {r.alertes}
                    </span>
                  ) : (
                    <span className="text-neutral-300">—</span>
                  )}
                </td>
              </tr>
            ))}
            {visibles.length === 0 ? (
              <tr>
                <td colSpan={9} className="px-4 py-8 text-center text-neutral-400">
                  Aucun magasin ne correspond à ces filtres.
                </td>
              </tr>
            ) : null}
          </tbody>
        </table>
      </div>
      <p className="px-1 text-xs text-neutral-400">
        {visibles.length} magasin{visibles.length > 1 ? 's' : ''} affiché{visibles.length > 1 ? 's' : ''}. Alerte = visite en
        retard sur la périodicité.
      </p>
    </div>
  );
}

function Th({
  label,
  k,
  sort,
  onSort,
  align = 'left',
}: {
  label: string;
  k: SortKey;
  sort: { key: SortKey; dir: 1 | -1 };
  onSort: (k: SortKey) => void;
  align?: 'left' | 'right' | 'center';
}) {
  const active = sort.key === k;
  return (
    <th className={`px-4 py-2.5 font-medium ${align === 'right' ? 'text-right' : align === 'center' ? 'text-center' : ''}`}>
      <button
        onClick={() => onSort(k)}
        className={`inline-flex items-center gap-1 transition hover:text-brand dark:hover:text-accent ${active ? 'text-brand dark:text-accent' : ''} ${align === 'right' ? 'flex-row-reverse' : ''}`}
      >
        {label}
        {active ? (sort.dir === 1 ? <ArrowUp size={12} /> : <ArrowDown size={12} />) : null}
      </button>
    </th>
  );
}
