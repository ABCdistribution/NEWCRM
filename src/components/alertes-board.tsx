'use client';

import { useMemo, useState } from 'react';
import {
  Search,
  Download,
  SlidersHorizontal,
  AlertCircle,
  AlertTriangle,
  Info,
  CheckCircle2,
  Phone,
  Eye,
  CalendarPlus,
  ClipboardCheck,
  Target,
} from 'lucide-react';

type Criticite = 'CRITIQUE' | 'ATTENTION' | 'INFO';
type AlerteType = 'baisse' | 'rupture' | 'frequence' | 'dn' | 'opportunite' | 'sav';

type CS = { code: string; nom: string; color: string };

const CS_LIST: Record<string, CS> = {
  CM: { code: 'CM', nom: 'Claire', color: 'bg-orange-500' },
  MD: { code: 'MD', nom: 'Marie', color: 'bg-fuchsia-500' },
  PL: { code: 'PL', nom: 'Pierre', color: 'bg-sky-500' },
  JP: { code: 'JP', nom: 'Julien', color: 'bg-emerald-500' },
  TB: { code: 'TB', nom: 'Thomas', color: 'bg-teal-500' },
  AS: { code: 'AS', nom: 'Sophie', color: 'bg-violet-500' },
};

type Alerte = {
  id: string;
  magasin: string;
  criticite: Criticite;
  type: AlerteType;
  motif: string;
  detail: string;
  signal: string;
  signalSub: string;
  cs: string;
  detecteLe: string;
  age: number; // jours
  action: string;
};

// Jeu de données représentatif (prototype — à brancher sur le moteur de détection).
const ALERTES: Alerte[] = [
  { id: 'a1', magasin: 'Système U Lyon Vaise', criticite: 'INFO', type: 'frequence', motif: 'Prochaine visite mensuelle dans 4j', detail: 'Anticiper la commande EDI', signal: '4j', signalSub: 'Prévu 22/05', cs: 'CM', detecteLe: '18 mai', age: 0, action: 'Préparer' },
  { id: 'a2', magasin: 'Système U Lyon Vaise', criticite: 'CRITIQUE', type: 'rupture', motif: 'Rupture EDI · risque déréférencement', detail: '3 références non livrées sur dernière commande', signal: '3 SKU', signalSub: '3 SKU', cs: 'CM', detecteLe: '17 mai', age: 1, action: 'Contacter' },
  { id: 'a3', magasin: 'Intermarché La Mézière', criticite: 'ATTENTION', type: 'dn', motif: 'Plan PEM incomplet en gondole', detail: '6 références manquantes (saisie promoteur Lucas)', signal: '6 réf.', signalSub: 'Saisie promoteur', cs: 'CM', detecteLe: '17 mai', age: 1, action: 'Voir DN' },
  { id: 'a4', magasin: 'Leclerc Évry 2', criticite: 'CRITIQUE', type: 'baisse', motif: 'Baisse CA -23 % sur 30 jours', detail: 'Concentré DPH (-31 %) et Entretien (-18 %)', signal: '-23 %', signalSub: '28 400 € → 21 800 €', cs: 'MD', detecteLe: '16 mai', age: 2, action: 'Planifier' },
  { id: 'a5', magasin: 'Auchan Vert Saint-Denis', criticite: 'INFO', type: 'opportunite', motif: 'Opportunité référencement PEM identifiée', detail: 'Marché potentiel 32 K€ détecté via patterns N-1', signal: '32 K€', signalSub: '32 K€', cs: 'PL', detecteLe: '16 mai', age: 2, action: 'Créer opp.' },
  { id: 'a6', magasin: 'Auchan Roncq', criticite: 'ATTENTION', type: 'frequence', motif: 'Visite trimestrielle dépassée', detail: '87 jours sans visite · règle Auchan : 90j max', signal: '87j', signalSub: 'Seuil : 90j', cs: 'JP', detecteLe: '15 mai', age: 3, action: 'Planifier' },
  { id: 'a7', magasin: 'Carrefour Market Nantes', criticite: 'CRITIQUE', type: 'sav', motif: 'Réclamation SAV non traitée', detail: 'Litige livraison ouvert depuis 5 jours', signal: '5j', signalSub: 'Ouvert 12/05', cs: 'JP', detecteLe: '15 mai', age: 3, action: 'Traiter' },
  { id: 'a8', magasin: 'Cora Bruay', criticite: 'ATTENTION', type: 'baisse', motif: 'Baisse commandes récurrentes', detail: 'Panier moyen -14 % vs trimestre précédent', signal: '-14 %', signalSub: 'Panier moyen', cs: 'MD', detecteLe: '14 mai', age: 4, action: 'Planifier' },
  { id: 'a9', magasin: 'Intermarché Vannes', criticite: 'INFO', type: 'opportunite', motif: 'Extension gamme solaire possible', detail: 'Saisonnalité favorable détectée', signal: '18 K€', signalSub: 'Potentiel', cs: 'PL', detecteLe: '13 mai', age: 5, action: 'Créer opp.' },
  { id: 'a10', magasin: 'Leclerc Blagnac', criticite: 'ATTENTION', type: 'dn', motif: 'DN concurrence en hausse', detail: '2 références concurrentes ajoutées en linéaire', signal: '2 réf.', signalSub: 'Relevé terrain', cs: 'TB', detecteLe: '13 mai', age: 5, action: 'Voir DN' },
  { id: 'a11', magasin: 'Système U Rennes', criticite: 'CRITIQUE', type: 'rupture', motif: 'Rupture stock article moteur', detail: 'Gencode 3401· 0 en stock depuis 2j', signal: '0 stock', signalSub: '2 jours', cs: 'AS', detecteLe: '12 mai', age: 6, action: 'Contacter' },
  { id: 'a12', magasin: 'Auchan Roncq', criticite: 'ATTENTION', type: 'frequence', motif: 'Fréquence de visite sous objectif', detail: 'Objectif mensuel non atteint', signal: '1/2', signalSub: 'visites/mois', cs: 'JP', detecteLe: '11 mai', age: 7, action: 'Planifier' },
];

const CRIT_STYLES: Record<Criticite, { badge: string; bar: string }> = {
  CRITIQUE: { badge: 'bg-red-500/12 text-red-600 dark:text-red-400', bar: 'bg-red-500' },
  ATTENTION: { badge: 'bg-amber-500/15 text-amber-600 dark:text-amber-400', bar: 'bg-amber-400' },
  INFO: { badge: 'bg-sky-500/12 text-sky-600 dark:text-sky-400', bar: 'bg-sky-500' },
};

const ACTION_ICONS: Record<string, typeof Phone> = {
  Préparer: ClipboardCheck,
  Contacter: Phone,
  'Voir DN': Eye,
  Planifier: CalendarPlus,
  'Créer opp.': Target,
  Traiter: CheckCircle2,
};

const TYPES: { key: AlerteType; label: string }[] = [
  { key: 'baisse', label: 'Baisse CA' },
  { key: 'frequence', label: 'Fréquence visite' },
  { key: 'rupture', label: 'Rupture EDI' },
  { key: 'dn', label: 'DN' },
  { key: 'sav', label: 'SAV' },
  { key: 'opportunite', label: 'Opportunité' },
];

const chipBase = 'inline-flex items-center gap-1.5 rounded-full border px-3 py-1 text-xs font-medium transition';
const chipOff = 'border-neutral-200 text-neutral-500 hover:border-neutral-300 dark:border-navy-700 dark:text-neutral-400';
const chipOn = 'border-neutral-900 bg-neutral-900 text-white dark:border-white dark:bg-white dark:text-navy-950';

function Chip({ active, onClick, children }: { active: boolean; onClick: () => void; children: React.ReactNode }) {
  return (
    <button type="button" onClick={onClick} className={`${chipBase} ${active ? chipOn : chipOff}`}>
      {children}
    </button>
  );
}

export function AlertesBoard() {
  const [crit, setCrit] = useState<'ALL' | Criticite>('ALL');
  const [type, setType] = useState<'ALL' | AlerteType>('ALL');
  const [cs, setCs] = useState<'ALL' | string>('ALL');
  const [q, setQ] = useState('');

  const counts = useMemo(() => ({
    total: ALERTES.length,
    CRITIQUE: ALERTES.filter((a) => a.criticite === 'CRITIQUE').length,
    ATTENTION: ALERTES.filter((a) => a.criticite === 'ATTENTION').length,
    INFO: ALERTES.filter((a) => a.criticite === 'INFO').length,
  }), []);

  const csPresent = useMemo(() => [...new Set(ALERTES.map((a) => a.cs))], []);

  const filtered = useMemo(() => {
    const query = q.trim().toLowerCase();
    return ALERTES.filter(
      (a) =>
        (crit === 'ALL' || a.criticite === crit) &&
        (type === 'ALL' || a.type === type) &&
        (cs === 'ALL' || a.cs === cs) &&
        (query === '' || a.magasin.toLowerCase().includes(query) || a.motif.toLowerCase().includes(query)),
    );
  }, [crit, type, cs, q]);

  const exportCsv = () => {
    const header = ['Magasin', 'Criticité', 'Type', 'Motif', 'Signal', 'CS', 'Détecté', 'Âge (j)'];
    const lines = filtered.map((a) => [a.magasin, a.criticite, a.type, a.motif, a.signal, CS_LIST[a.cs]?.nom ?? a.cs, a.detecteLe, String(a.age)]);
    const csv = [header, ...lines].map((r) => r.map((c) => `"${String(c).replace(/"/g, '""')}"`).join(';')).join('\n');
    const blob = new Blob(['﻿' + csv], { type: 'text/csv;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = 'alertes.csv';
    link.click();
    URL.revokeObjectURL(url);
  };

  return (
    <div className="flex flex-col gap-5">
      {/* En-tête */}
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold">Centre d&apos;alertes</h1>
          <p className="mt-0.5 text-sm text-neutral-500">
            Moteur de détection basé sur les données Minos · sync J-1 09:42 · {counts.total} sur {counts.total} alertes
          </p>
        </div>
        <div className="flex items-center gap-2">
          <button
            type="button"
            title="Configuration des règles de détection (à venir)"
            className="inline-flex items-center gap-1.5 rounded-lg border border-neutral-200 px-3 py-2 text-sm font-medium text-neutral-600 transition hover:bg-neutral-50 dark:border-navy-700 dark:text-neutral-300 dark:hover:bg-navy-800"
          >
            <SlidersHorizontal size={15} /> Règles
          </button>
          <button
            type="button"
            onClick={exportCsv}
            className="inline-flex items-center gap-1.5 rounded-lg border border-neutral-200 px-3 py-2 text-sm font-medium text-neutral-600 transition hover:bg-neutral-50 dark:border-navy-700 dark:text-neutral-300 dark:hover:bg-navy-800"
          >
            <Download size={15} /> Exporter
          </button>
        </div>
      </div>

      {/* KPIs criticité */}
      <section className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <KpiCard tone="red" icon={AlertCircle} label="Critiques" value={counts.CRITIQUE} sub={`${counts.CRITIQUE} magasins concernés`} />
        <KpiCard tone="amber" icon={AlertTriangle} label="Attention" value={counts.ATTENTION} sub="À traiter sous 7j" />
        <KpiCard tone="sky" icon={Info} label="Info" value={counts.INFO} sub="Opportunités détectées" />
        <KpiCard tone="emerald" icon={CheckCircle2} label="Traitées 30j" value={47} sub="Délai moy. 3,2j" subPill />
      </section>

      {/* Recherche */}
      <div className="flex items-center gap-2 rounded-xl border border-neutral-200 bg-white px-3 py-2 shadow-card dark:border-navy-700">
        <Search size={15} className="shrink-0 text-neutral-400" />
        <input
          value={q}
          onChange={(e) => setQ(e.target.value)}
          placeholder="Filtrer par magasin ou motif…"
          className="w-full bg-transparent text-sm outline-none placeholder:text-neutral-400"
        />
      </div>

      {/* Filtres */}
      <div className="flex flex-col gap-2.5">
        <div className="flex flex-wrap items-center gap-2">
          <span className="mr-1 text-[11px] font-semibold uppercase tracking-wide text-neutral-400">Criticité</span>
          <Chip active={crit === 'ALL'} onClick={() => setCrit('ALL')}>Toutes <b className="opacity-60">{counts.total}</b></Chip>
          <Chip active={crit === 'CRITIQUE'} onClick={() => setCrit('CRITIQUE')}>Critiques <b className="opacity-60">{counts.CRITIQUE}</b></Chip>
          <Chip active={crit === 'ATTENTION'} onClick={() => setCrit('ATTENTION')}>Attention <b className="opacity-60">{counts.ATTENTION}</b></Chip>
          <Chip active={crit === 'INFO'} onClick={() => setCrit('INFO')}>Info <b className="opacity-60">{counts.INFO}</b></Chip>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <span className="mr-1 text-[11px] font-semibold uppercase tracking-wide text-neutral-400">Type</span>
          <Chip active={type === 'ALL'} onClick={() => setType('ALL')}>Tous</Chip>
          {TYPES.map((t) => (
            <Chip key={t.key} active={type === t.key} onClick={() => setType(t.key)}>{t.label}</Chip>
          ))}
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <span className="mr-1 text-[11px] font-semibold uppercase tracking-wide text-neutral-400">CS</span>
          <Chip active={cs === 'ALL'} onClick={() => setCs('ALL')}>Tous</Chip>
          {csPresent.map((c) => (
            <Chip key={c} active={cs === c} onClick={() => setCs(c)}>{c}</Chip>
          ))}
        </div>
      </div>

      {/* Tableau */}
      <div className="overflow-x-auto rounded-xl bg-white shadow-card">
        <table className="w-full text-sm">
          <thead className="bg-neutral-50 text-left text-neutral-500 dark:bg-navy-950/50">
            <tr>
              <th className="px-4 py-2.5 font-medium">Magasin / motif</th>
              <th className="px-4 py-2.5 font-medium">Type</th>
              <th className="px-4 py-2.5 font-medium">Signal</th>
              <th className="px-4 py-2.5 font-medium">CS</th>
              <th className="px-4 py-2.5 font-medium">Détecté</th>
              <th className="px-4 py-2.5 font-medium">Âge</th>
              <th className="px-4 py-2.5 text-right font-medium">Action</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-neutral-100 dark:divide-navy-700">
            {filtered.map((a) => {
              const cst = CRIT_STYLES[a.criticite];
              const ActionIcon = ACTION_ICONS[a.action] ?? CalendarPlus;
              const agent = CS_LIST[a.cs];
              return (
                <tr key={a.id} className="hover:bg-neutral-50 dark:hover:bg-navy-800/50">
                  <td className="py-3 pl-0 pr-4">
                    <div className="flex gap-3">
                      <span className={`w-1 shrink-0 rounded-full ${cst.bar}`} />
                      <div className="min-w-0">
                        <p className="flex items-center gap-2 font-medium">
                          {a.magasin}
                          <span className={`rounded-full px-1.5 py-0.5 text-[10px] font-semibold uppercase ${cst.badge}`}>{a.criticite}</span>
                        </p>
                        <p className="text-sm text-neutral-600 dark:text-neutral-300">{a.motif}</p>
                        <p className="font-mono text-[11px] text-neutral-400">{a.detail}</p>
                      </div>
                    </div>
                  </td>
                  <td className="px-4 py-3">
                    <span className="rounded-md bg-neutral-100 px-2 py-0.5 font-mono text-xs text-neutral-500 dark:bg-navy-800">{a.type}</span>
                  </td>
                  <td className="px-4 py-3">
                    <p className="font-semibold">{a.signal}</p>
                    <p className="text-[11px] text-neutral-400">{a.signalSub}</p>
                  </td>
                  <td className="px-4 py-3">
                    <span className="inline-flex items-center gap-2">
                      <span className={`flex h-6 w-6 items-center justify-center rounded-full text-[10px] font-bold text-white ${agent?.color ?? 'bg-neutral-400'}`}>
                        {a.cs}
                      </span>
                      <span className="text-neutral-600 dark:text-neutral-300">{agent?.nom ?? a.cs}</span>
                    </span>
                  </td>
                  <td className="px-4 py-3 text-neutral-500">{a.detecteLe}</td>
                  <td className="px-4 py-3">
                    <span className={`font-mono text-xs ${a.age === 0 ? 'text-neutral-400' : a.age >= 4 ? 'text-red-500' : 'text-amber-500'}`}>
                      {a.age === 0 ? 'auj.' : `${a.age}j`}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-right">
                    <button
                      type="button"
                      className="inline-flex items-center gap-1.5 rounded-lg border border-neutral-200 px-2.5 py-1.5 text-xs font-medium text-neutral-600 transition hover:border-brand hover:text-brand dark:border-navy-700 dark:text-neutral-300 dark:hover:border-accent dark:hover:text-accent"
                    >
                      <ActionIcon size={13} /> {a.action}
                    </button>
                  </td>
                </tr>
              );
            })}
            {filtered.length === 0 ? (
              <tr>
                <td colSpan={7} className="px-4 py-10 text-center text-neutral-400">Aucune alerte pour ces filtres.</td>
              </tr>
            ) : null}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function KpiCard({
  tone,
  icon: Icon,
  label,
  value,
  sub,
  subPill,
}: {
  tone: 'red' | 'amber' | 'sky' | 'emerald';
  icon: typeof Info;
  label: string;
  value: number;
  sub: string;
  subPill?: boolean;
}) {
  const bar = {
    red: 'from-red-400 to-red-500',
    amber: 'from-amber-300 to-amber-400',
    sky: 'from-sky-400 to-sky-500',
    emerald: 'from-emerald-400 to-emerald-500',
  }[tone];
  const ic = {
    red: 'text-red-500',
    amber: 'text-amber-500',
    sky: 'text-sky-500',
    emerald: 'text-emerald-500',
  }[tone];
  return (
    <div className="relative overflow-hidden rounded-2xl bg-white p-5 shadow-card">
      <span className={`absolute inset-x-0 top-0 h-0.5 bg-gradient-to-r ${bar}`} />
      <div className="flex items-start justify-between">
        <span className="text-[11px] font-semibold uppercase tracking-wide text-neutral-500">{label}</span>
        <Icon size={16} className={ic} />
      </div>
      <p className="mt-2 text-3xl font-bold tabular-nums">{value}</p>
      {subPill ? (
        <span className="mt-1.5 inline-flex rounded-full bg-emerald-500/12 px-1.5 py-0.5 text-[11px] font-semibold text-emerald-600 dark:text-emerald-400">{sub}</span>
      ) : (
        <p className="mt-1.5 text-xs text-neutral-400">{sub}</p>
      )}
    </div>
  );
}
