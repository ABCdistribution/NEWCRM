'use client';

import { useEffect, useMemo, useState } from 'react';
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
  Plus,
  Trash2,
  X,
} from 'lucide-react';
import { ClassBadge } from './class-badge';

// Classification magasin (A→G) par point de vente — remontée du référentiel.
const CLASSE_MAGASIN: Record<string, string> = {
  'Système U Lyon Vaise': 'A',
  'Intermarché La Mézière': 'B',
  'Leclerc Évry 2': 'A',
  'Auchan Vert Saint-Denis': 'B',
  'Auchan Roncq': 'C',
  'Carrefour Market Nantes': 'C',
  'Cora Bruay': 'B',
  'Intermarché Vannes': 'D',
  'Leclerc Blagnac': 'A',
  'Système U Rennes': 'B',
};

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

const chipBase = 'inline-flex items-center gap-1.5 rounded-full border px-3 py-1.5 text-xs font-medium transition';
const chipOff = 'border-neutral-200 bg-white text-neutral-600 hover:border-brand/50 hover:text-brand dark:border-navy-700 dark:bg-navy-900 dark:text-neutral-300 dark:hover:border-brand';
const chipOn = 'border-brand bg-brand text-white shadow-sm';
const selectCls = 'rounded-full border border-neutral-200 bg-white px-3 py-1.5 text-xs font-medium text-neutral-600 outline-none transition focus:border-brand dark:border-navy-700 dark:bg-navy-900 dark:text-neutral-300';

function Chip({ active, onClick, children }: { active: boolean; onClick: () => void; children: React.ReactNode }) {
  return (
    <button type="button" onClick={onClick} className={`${chipBase} ${active ? chipOn : chipOff}`}>
      {children}
    </button>
  );
}

// --- Règles de détection (configuration admin) -----------------------------

type Regle = {
  id: string;
  type: AlerteType;
  seuil: number;
  criticite: Criticite;
  actif: boolean;
  /** Classes de magasin ciblées (A++, A+, …) — vide = toutes les classes. */
  classes: string[];
};

/** Classification magasin utilisée pour cibler une règle. */
const CLASSES_MAGASIN = ['A++', 'A+', 'A', 'B', 'C', 'D', 'E', 'F', 'G'];

/** Unité et libellé du seuil selon le type de règle. */
const SEUILS: Record<AlerteType, { unite: string; hint: string }> = {
  baisse: { unite: '%', hint: 'Baisse de CA sur 30 jours (en %)' },
  frequence: { unite: 'j', hint: 'Jours sans visite au-delà de la périodicité' },
  rupture: { unite: 'SKU', hint: 'Références non livrées sur la dernière commande' },
  dn: { unite: 'réf.', hint: 'Références concurrentes gagnées en linéaire' },
  sav: { unite: 'j', hint: 'Jours sans traitement d’une réclamation' },
  opportunite: { unite: 'K€', hint: 'Potentiel détecté (patterns N-1)' },
};

const REGLES_DEFAUT: Regle[] = [
  { id: 'r1', type: 'baisse', seuil: 20, criticite: 'CRITIQUE', actif: true, classes: [] },
  { id: 'r2', type: 'baisse', seuil: 12, criticite: 'ATTENTION', actif: true, classes: [] },
  { id: 'r3', type: 'frequence', seuil: 90, criticite: 'ATTENTION', actif: true, classes: [] },
  // Les grands comptes se surveillent de plus près : seuil resserré sur A++ / A+.
  { id: 'r8', type: 'frequence', seuil: 30, criticite: 'CRITIQUE', actif: true, classes: ['A++', 'A+'] },
  { id: 'r4', type: 'rupture', seuil: 2, criticite: 'CRITIQUE', actif: true, classes: [] },
  { id: 'r5', type: 'dn', seuil: 2, criticite: 'ATTENTION', actif: true, classes: [] },
  { id: 'r6', type: 'sav', seuil: 3, criticite: 'CRITIQUE', actif: true, classes: [] },
  { id: 'r7', type: 'opportunite', seuil: 15, criticite: 'INFO', actif: true, classes: [] },
];

const REGLES_STORAGE = 'helios.alertes.regles';

function typeLabel(type: AlerteType): string {
  return TYPES.find((t) => t.key === type)?.label ?? type;
}

/** Modal de configuration : ajuster seuils/criticités, activer, supprimer, ajouter. */
function ReglesModal({ onClose }: { onClose: () => void }) {
  // Monté uniquement côté client (à l'ouverture) — localStorage accessible, pas de mismatch SSR.
  const [regles, setRegles] = useState<Regle[]>(() => {
    try {
      const raw = localStorage.getItem(REGLES_STORAGE);
      // Compat : les règles enregistrées avant le ciblage par classe n'ont pas `classes`.
      if (raw) return (JSON.parse(raw) as Regle[]).map((r) => ({ ...r, classes: r.classes ?? [] }));
    } catch {}
    return REGLES_DEFAUT;
  });
  const [newType, setNewType] = useState<AlerteType>('baisse');
  const [newSeuil, setNewSeuil] = useState('');
  const [newCrit, setNewCrit] = useState<Criticite>('ATTENTION');
  const [newClasses, setNewClasses] = useState<string[]>([]);

  useEffect(() => {
    try {
      localStorage.setItem(REGLES_STORAGE, JSON.stringify(regles));
    } catch {}
  }, [regles]);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    document.addEventListener('keydown', onKey);
    document.body.style.overflow = 'hidden';
    return () => {
      document.removeEventListener('keydown', onKey);
      document.body.style.overflow = '';
    };
  }, [onClose]);

  const patch = (id: string, p: Partial<Regle>) =>
    setRegles((rs) => rs.map((r) => (r.id === id ? { ...r, ...p } : r)));

  const ajouter = () => {
    const seuil = Number(newSeuil);
    if (!newSeuil || Number.isNaN(seuil) || seuil <= 0) return;
    setRegles((rs) => [
      ...rs,
      { id: `r${Date.now()}`, type: newType, seuil, criticite: newCrit, actif: true, classes: newClasses },
    ]);
    setNewSeuil('');
    setNewClasses([]);
  };

  /** Bascule une classe dans une liste (vide = toutes les classes). */
  const toggleClasse = (list: string[], c: string): string[] =>
    list.includes(c) ? list.filter((x) => x !== c) : [...list, c];

  const classeChip = (active: boolean) =>
    `rounded-md px-1.5 py-0.5 text-[10px] font-bold transition ${
      active
        ? 'bg-brand text-white dark:bg-accent dark:text-brand'
        : 'bg-neutral-100 text-neutral-400 hover:text-neutral-600 dark:bg-navy-800 dark:hover:text-neutral-200'
    }`;

  const inputCls =
    'rounded-lg border border-neutral-200 bg-white px-2 py-1.5 text-xs outline-none transition focus:border-brand dark:border-navy-600 dark:bg-navy-950 dark:focus:border-accent';

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4" role="dialog" aria-modal="true" aria-label="Règles de détection">
      <button type="button" className="absolute inset-0 bg-black/50" aria-label="Fermer" onClick={onClose} />
      <div className="relative flex max-h-[85vh] w-full max-w-2xl flex-col overflow-hidden rounded-2xl bg-white shadow-2xl dark:bg-navy-900">
        {/* En-tête */}
        <div className="flex items-center gap-2 border-b border-neutral-100 px-5 py-4 dark:border-navy-700">
          <SlidersHorizontal size={17} className="text-brand dark:text-accent" />
          <div className="min-w-0 flex-1">
            <h2 className="text-base font-semibold">Règles de détection</h2>
            <p className="text-xs text-neutral-400">
              Seuils qui déclenchent les alertes du moteur — appliqués à la prochaine synchronisation Minos.
            </p>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="rounded-lg p-2 text-neutral-400 transition hover:bg-neutral-100 dark:hover:bg-navy-800"
            aria-label="Fermer"
          >
            <X size={18} />
          </button>
        </div>

        {/* Liste des règles */}
        <ul className="flex-1 divide-y divide-neutral-100 overflow-y-auto px-5 dark:divide-navy-700">
          {regles.map((r) => (
            <li key={r.id} className={`flex flex-wrap items-center gap-3 py-3 ${r.actif ? '' : 'opacity-50'}`}>
              {/* Interrupteur actif */}
              <button
                type="button"
                role="switch"
                aria-checked={r.actif}
                onClick={() => patch(r.id, { actif: !r.actif })}
                className={`relative h-5 w-9 shrink-0 rounded-full transition ${r.actif ? 'bg-brand dark:bg-accent' : 'bg-neutral-300 dark:bg-navy-600'}`}
                title={r.actif ? 'Désactiver la règle' : 'Activer la règle'}
              >
                <span
                  className={`absolute top-0.5 h-4 w-4 rounded-full bg-white transition-all ${r.actif ? 'left-4.5' : 'left-0.5'}`}
                />
              </button>

              <div className="min-w-0 flex-1">
                <p className="text-sm font-medium">{typeLabel(r.type)}</p>
                <p className="text-[11px] text-neutral-400">{SEUILS[r.type].hint}</p>
                {/* Ciblage par classe de magasin — aucune sélection = toutes. */}
                <div className="mt-1 flex flex-wrap items-center gap-1">
                  <button
                    type="button"
                    onClick={() => patch(r.id, { classes: [] })}
                    className={classeChip(r.classes.length === 0)}
                  >
                    Toutes
                  </button>
                  {CLASSES_MAGASIN.map((c) => (
                    <button
                      key={c}
                      type="button"
                      onClick={() => patch(r.id, { classes: toggleClasse(r.classes, c) })}
                      className={classeChip(r.classes.includes(c))}
                      title={`Classe ${c}`}
                    >
                      {c}
                    </button>
                  ))}
                </div>
              </div>

              {/* Seuil */}
              <label className="flex items-center gap-1 text-xs text-neutral-500">
                Seuil
                <input
                  type="number"
                  min={1}
                  value={r.seuil}
                  onChange={(e) => patch(r.id, { seuil: Number(e.target.value) })}
                  className={`${inputCls} w-16 text-right tabular-nums`}
                />
                <span className="w-7 text-neutral-400">{SEUILS[r.type].unite}</span>
              </label>

              {/* Criticité */}
              <select
                value={r.criticite}
                onChange={(e) => patch(r.id, { criticite: e.target.value as Criticite })}
                className={inputCls}
                aria-label="Criticité"
              >
                <option value="CRITIQUE">Critique</option>
                <option value="ATTENTION">Attention</option>
                <option value="INFO">Info</option>
              </select>

              <button
                type="button"
                onClick={() => setRegles((rs) => rs.filter((x) => x.id !== r.id))}
                className="rounded-lg p-1.5 text-neutral-400 transition hover:bg-red-50 hover:text-red-500 dark:hover:bg-red-950/40"
                aria-label={`Supprimer la règle ${typeLabel(r.type)}`}
              >
                <Trash2 size={14} />
              </button>
            </li>
          ))}
          {regles.length === 0 ? (
            <li className="py-8 text-center text-sm text-neutral-400">Aucune règle — le moteur ne détecte plus rien.</li>
          ) : null}
        </ul>

        {/* Ajout d'une règle */}
        <div className="border-t border-neutral-100 bg-neutral-50 px-5 py-4 dark:border-navy-700 dark:bg-navy-950/40">
          <p className="mb-2 text-[11px] font-semibold uppercase tracking-wider text-neutral-400">Ajouter une règle</p>
          <div className="flex flex-wrap items-center gap-2">
            <select
              value={newType}
              onChange={(e) => setNewType(e.target.value as AlerteType)}
              className={inputCls}
              aria-label="Type de règle"
            >
              {TYPES.map((t) => (
                <option key={t.key} value={t.key}>{t.label}</option>
              ))}
            </select>
            <label className="flex items-center gap-1 text-xs text-neutral-500">
              Seuil
              <input
                type="number"
                min={1}
                value={newSeuil}
                onChange={(e) => setNewSeuil(e.target.value)}
                placeholder="—"
                className={`${inputCls} w-16 text-right tabular-nums`}
              />
              <span className="w-7 text-neutral-400">{SEUILS[newType].unite}</span>
            </label>
            <select
              value={newCrit}
              onChange={(e) => setNewCrit(e.target.value as Criticite)}
              className={inputCls}
              aria-label="Criticité de la nouvelle règle"
            >
              <option value="CRITIQUE">Critique</option>
              <option value="ATTENTION">Attention</option>
              <option value="INFO">Info</option>
            </select>
            <button
              type="button"
              onClick={ajouter}
              disabled={!newSeuil || Number(newSeuil) <= 0}
              className="inline-flex items-center gap-1.5 rounded-lg bg-brand px-3 py-1.5 text-xs font-semibold text-white transition hover:bg-brand/90 disabled:opacity-40 dark:bg-accent dark:text-brand"
            >
              <Plus size={13} /> Ajouter
            </button>
            <span className="ml-auto text-[11px] text-neutral-400">{SEUILS[newType].hint}</span>
          </div>
          {/* Classes ciblées par la nouvelle règle (vide = toutes). */}
          <div className="mt-2 flex flex-wrap items-center gap-1">
            <span className="mr-1 text-[10px] font-semibold uppercase tracking-wider text-neutral-400">Classes</span>
            <button type="button" onClick={() => setNewClasses([])} className={classeChip(newClasses.length === 0)}>
              Toutes
            </button>
            {CLASSES_MAGASIN.map((c) => (
              <button
                key={c}
                type="button"
                onClick={() => setNewClasses((cs) => toggleClasse(cs, c))}
                className={classeChip(newClasses.includes(c))}
              >
                {c}
              </button>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

export function AlertesBoard({ canManageRules }: { canManageRules: boolean }) {
  const [crit, setCrit] = useState<'ALL' | Criticite>('ALL');
  const [type, setType] = useState<'ALL' | AlerteType>('ALL');
  const [q, setQ] = useState('');
  const [reglesOpen, setReglesOpen] = useState(false);

  const counts = useMemo(() => ({
    total: ALERTES.length,
    CRITIQUE: ALERTES.filter((a) => a.criticite === 'CRITIQUE').length,
    ATTENTION: ALERTES.filter((a) => a.criticite === 'ATTENTION').length,
    INFO: ALERTES.filter((a) => a.criticite === 'INFO').length,
  }), []);

  const filtered = useMemo(() => {
    const query = q.trim().toLowerCase();
    return ALERTES.filter(
      (a) =>
        (crit === 'ALL' || a.criticite === crit) &&
        (type === 'ALL' || a.type === type) &&
        (query === '' || a.magasin.toLowerCase().includes(query) || a.motif.toLowerCase().includes(query)),
    );
  }, [crit, type, q]);

  const exportCsv = () => {
    const header = ['Magasin', 'Classe', 'Criticité', 'Type', 'Motif', 'Signal', 'CS', 'Détecté', 'Âge (j)'];
    const lines = filtered.map((a) => [a.magasin, CLASSE_MAGASIN[a.magasin] ?? '', a.criticite, a.type, a.motif, a.signal, CS_LIST[a.cs]?.nom ?? a.cs, a.detecteLe, String(a.age)]);
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
        </div>
        <div className="flex items-center gap-2">
          {canManageRules ? (
            <button
              type="button"
              onClick={() => setReglesOpen(true)}
              title="Configuration des règles de détection (réservé à l'administration)"
              className="inline-flex items-center gap-1.5 rounded-lg border border-neutral-200 px-3 py-2 text-sm font-medium text-neutral-600 transition hover:bg-neutral-50 dark:border-navy-700 dark:text-neutral-300 dark:hover:bg-navy-800"
            >
              <SlidersHorizontal size={15} /> Règles
            </button>
          ) : null}
          {reglesOpen ? <ReglesModal onClose={() => setReglesOpen(false)} /> : null}
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

      {/* Filtres : criticité (pills) + type (menu) */}
      <div className="flex flex-wrap items-center gap-2">
        <Chip active={crit === 'ALL'} onClick={() => setCrit('ALL')}>Toutes <b className="opacity-70">{counts.total}</b></Chip>
        <Chip active={crit === 'CRITIQUE'} onClick={() => setCrit('CRITIQUE')}>Critiques <b className="opacity-70">{counts.CRITIQUE}</b></Chip>
        <Chip active={crit === 'ATTENTION'} onClick={() => setCrit('ATTENTION')}>Attention <b className="opacity-70">{counts.ATTENTION}</b></Chip>
        <Chip active={crit === 'INFO'} onClick={() => setCrit('INFO')}>Info <b className="opacity-70">{counts.INFO}</b></Chip>
        <span className="mx-1 hidden h-5 w-px bg-neutral-200 sm:block dark:bg-navy-700" />
        <select value={type} onChange={(e) => setType(e.target.value as typeof type)} className={selectCls} aria-label="Filtrer par type">
          <option value="ALL">Tous les types</option>
          {TYPES.map((t) => (
            <option key={t.key} value={t.key}>{t.label}</option>
          ))}
        </select>
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
                          <ClassBadge value={CLASSE_MAGASIN[a.magasin] ?? null} size="xs" />
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
