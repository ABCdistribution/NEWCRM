'use client';

import { useMemo, useState } from 'react';
import { Users, TrendingUp, TrendingDown, Minus, Search } from 'lucide-react';
import { StatTile } from './stat-tile';
import { ActiveBadge, ROLE_LABELS } from './badges';
import { PromoteurModal } from './promoteur-modal';

export type Membre = {
  id: string;
  displayName: string;
  username: string;
  role: string;
  isActive: boolean;
  idRepr: string | null;
  secteur: { id: string; code: string; nom: string } | null;
  region: { id: string; code: string; nom: string } | null;
  ca: number | null;
  deltaPct: number | null;
  tauxPct: number | null;
};

const EUR = new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR', maximumFractionDigits: 0 });
const card = 'rounded-2xl bg-white shadow-card overflow-hidden';
const cardHeader = 'flex flex-wrap items-center gap-x-3 gap-y-1 border-b border-neutral-100 px-5 py-3 dark:border-navy-700';

function Delta({ pct }: { pct: number | null }) {
  if (pct == null) return <span className="inline-flex items-center gap-1 text-xs text-neutral-400"><Minus size={12} /> n/d</span>;
  const up = pct >= 0;
  return (
    <span className={`inline-flex items-center gap-1 text-xs font-semibold ${up ? 'text-emerald-500' : 'text-red-400'}`}>
      {up ? <TrendingUp size={13} /> : <TrendingDown size={13} />}
      {up ? '+' : ''}{pct}%
    </span>
  );
}

function Taux({ pct }: { pct: number | null }) {
  if (pct == null) return <span className="text-xs text-neutral-400">—</span>;
  return (
    <span className={`text-xs font-semibold ${pct >= 100 ? 'text-emerald-500' : pct >= 70 ? 'text-amber-400' : 'text-red-400'}`}>
      {pct}%
    </span>
  );
}

export function MonEquipeBoard({ team, meName }: { team: Membre[]; meName: string }) {
  const [q, setQ] = useState('');
  const [actifsOnly, setActifsOnly] = useState(false);
  const [sortKey, setSortKey] = useState<'ca' | 'objectif' | 'nom'>('ca');
  const [selected, setSelected] = useState<Membre | null>(null);

  // KPIs — calculés sur toute l'équipe (indépendants des filtres).
  const kpis = useMemo(() => {
    const zones = new Set(team.map((m) => m.secteur?.id ?? m.region?.id ?? '—'));
    return {
      effectif: team.length,
      actifs: team.filter((m) => m.isActive).length,
      caEquipe: team.reduce((s, m) => s + (m.ca ?? 0), 0),
      enBaisse: team.filter((m) => m.deltaPct != null && m.deltaPct < 0).length,
      zones: zones.size,
    };
  }, [team]);

  const sortFn = useMemo(() => {
    if (sortKey === 'nom') return (a: Membre, b: Membre) => a.displayName.localeCompare(b.displayName);
    if (sortKey === 'objectif') return (a: Membre, b: Membre) => (b.tauxPct ?? -1) - (a.tauxPct ?? -1);
    return (a: Membre, b: Membre) => (b.ca ?? 0) - (a.ca ?? 0);
  }, [sortKey]);

  const groupes = useMemo(() => {
    const query = q.trim().toLowerCase();
    const filtered = team.filter(
      (m) =>
        (!actifsOnly || m.isActive) &&
        (query === '' || m.displayName.toLowerCase().includes(query) || (m.idRepr ?? '').includes(query)),
    );
    // Regroupement par secteur ; à défaut par région (jamais de bucket « sans secteur »).
    const map = new Map<string, { nom: string; membres: Membre[] }>();
    for (const m of filtered) {
      const key = m.secteur?.id ?? m.region?.id ?? '__none__';
      const nom = m.secteur ? `${m.secteur.nom} (${m.secteur.code})` : m.region ? m.region.nom : 'Non rattaché';
      if (!map.has(key)) map.set(key, { nom, membres: [] });
      map.get(key)!.membres.push(m);
    }
    return [...map.values()]
      .map((g) => ({
        ...g,
        membres: [...g.membres].sort(sortFn),
        caSecteur: g.membres.reduce((s, m) => s + (m.ca ?? 0), 0),
        enBaisse: g.membres.filter((m) => m.deltaPct != null && m.deltaPct < 0).length,
      }))
      .sort((a, b) => a.nom.localeCompare(b.nom));
  }, [team, q, actifsOnly, sortFn]);

  const selectCls = 'rounded-lg border border-neutral-200 bg-white px-2.5 py-2 text-sm outline-none focus:border-brand dark:border-navy-700 dark:bg-navy-950';

  return (
    <div className="flex flex-col gap-5">
      <div>
        <h1 className="text-2xl font-bold">Mon équipe</h1>
        <p className="text-sm text-neutral-500">Vos collaborateurs directs et leur performance du mois — {meName}.</p>
      </div>

      {/* KPIs */}
      <section className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <StatTile icon={Users} label="Collaborateurs" value={String(kpis.effectif)} hint={`${kpis.actifs} actif(s)`} />
        <StatTile icon={TrendingUp} label="CA équipe (mois)" value={EUR.format(kpis.caEquipe)} hint="Somme des codes repr." />
        <StatTile icon={TrendingDown} label="En baisse vs N-1" value={String(kpis.enBaisse)} hint="À suivre en priorité" />
        <StatTile icon={Users} label="Territoires" value={String(kpis.zones)} hint="Secteurs / régions couverts" />
      </section>

      {/* Barre d'outils */}
      <div className="flex flex-wrap items-center gap-2">
        <div className="flex min-w-56 flex-1 items-center gap-2 rounded-xl border border-neutral-200 bg-white px-3 py-2 shadow-card dark:border-navy-700 dark:bg-navy-950">
          <Search size={15} className="shrink-0 text-neutral-400" />
          <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Nom ou code représentant…" className="w-full bg-transparent text-sm outline-none placeholder:text-neutral-400" />
        </div>
        <label className="inline-flex cursor-pointer items-center gap-2 rounded-lg border border-neutral-200 px-3 py-2 text-sm text-neutral-600 dark:border-navy-700 dark:text-neutral-300">
          <input type="checkbox" checked={actifsOnly} onChange={(e) => setActifsOnly(e.target.checked)} className="accent-brand" />
          Actifs seulement
        </label>
        <select value={sortKey} onChange={(e) => setSortKey(e.target.value as typeof sortKey)} className={selectCls} aria-label="Trier par">
          <option value="ca">Trier : CA décroissant</option>
          <option value="objectif">Trier : atteinte objectif</option>
          <option value="nom">Trier : nom</option>
        </select>
      </div>

      {groupes.length === 0 ? (
        <p className="rounded-2xl bg-white px-5 py-8 text-center text-sm text-neutral-400 shadow-card">
          Aucun collaborateur pour ces filtres.
        </p>
      ) : (
        groupes.map((g) => (
          <section key={g.nom} className={card}>
            <h2 className={cardHeader}>
              <Users size={16} className="text-brand dark:text-accent" />
              <span className="font-semibold">{g.nom}</span>
              <span className="text-xs font-normal text-neutral-400">
                {g.membres.length} membre{g.membres.length > 1 ? 's' : ''}
              </span>
              <span className="ml-auto flex items-center gap-3 text-xs">
                <span className="text-neutral-500">
                  CA secteur <span className="font-semibold text-brand dark:text-accent">{EUR.format(g.caSecteur)}</span>
                </span>
                {g.enBaisse > 0 ? (
                  <span className="inline-flex items-center gap-1 rounded-full bg-red-500/10 px-2 py-0.5 font-semibold text-red-500">
                    <TrendingDown size={12} /> {g.enBaisse} en baisse
                  </span>
                ) : null}
              </span>
            </h2>
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead className="text-left text-xs text-neutral-400">
                  <tr>
                    <th className="px-5 py-2 font-medium">Collaborateur</th>
                    <th className="px-2 py-2 font-medium">Rôle</th>
                    <th className="px-2 py-2 text-right font-medium">CA</th>
                    <th className="px-2 py-2 text-right font-medium">vs N-1</th>
                    <th className="px-2 py-2 text-right font-medium">Objectif</th>
                    <th className="px-5 py-2 text-right font-medium">Statut</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-neutral-100 dark:divide-navy-700">
                  {g.membres.map((m) => (
                    <tr
                      key={m.id}
                      onClick={() => setSelected(m)}
                      className={`cursor-pointer hover:bg-neutral-50 dark:hover:bg-navy-800/50 ${m.isActive ? '' : 'opacity-50'}`}
                    >
                      <td className="px-5 py-2.5">
                        <p className="font-medium">{m.displayName}</p>
                        <p className="font-mono text-[11px] text-neutral-400">
                          {m.username}
                          {m.idRepr ? ` · code ${m.idRepr}` : ''}
                        </p>
                      </td>
                      <td className="px-2 py-2.5 text-xs text-neutral-500">{ROLE_LABELS[m.role] ?? m.role}</td>
                      <td className="px-2 py-2.5 text-right font-semibold dark:text-accent">
                        {m.ca != null ? EUR.format(m.ca) : <span className="text-xs text-neutral-400">—</span>}
                      </td>
                      <td className="px-2 py-2.5 text-right"><Delta pct={m.deltaPct} /></td>
                      <td className="px-2 py-2.5 text-right"><Taux pct={m.tauxPct} /></td>
                      <td className="px-5 py-2.5 text-right"><ActiveBadge active={m.isActive} /></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </section>
        ))
      )}

      {selected ? <PromoteurModal membre={selected} onClose={() => setSelected(null)} /> : null}
    </div>
  );
}
