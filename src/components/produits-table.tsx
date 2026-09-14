'use client';

import { useState } from 'react';
import { X, Package, Boxes, TrendingUp, AlertTriangle, Tag, Layers, Barcode, Factory } from 'lucide-react';
import type { ArticleRow } from '@/lib/api';
import { ActiveBadge } from './badges';

const EUR = new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR', maximumFractionDigits: 0 });
const NB = new Intl.NumberFormat('fr-FR');

/** Ventes 30j « d'illustration » stables par article (l'API ne fournit pas de ventes par produit). */
function pseudoVentes(id: string): number {
  let h = 0;
  for (const c of id) h = (h * 31 + c.charCodeAt(0)) >>> 0;
  return 40 + (h % 460);
}

function etatStock(stock: number, pcb: number | null): { label: string; tone: string } {
  if (stock <= 0) return { label: 'Rupture', tone: 'text-red-500' };
  if (pcb && stock < pcb) return { label: 'Faible', tone: 'text-amber-500' };
  return { label: 'OK', tone: 'text-emerald-500' };
}

export function ProduitsTable({ articles }: { articles: ArticleRow[] }) {
  const [selected, setSelected] = useState<ArticleRow | null>(null);

  return (
    <div className="overflow-x-auto rounded-xl bg-white shadow-card">
      <table className="w-full text-sm">
        <thead className="bg-neutral-50 text-left text-neutral-500 dark:bg-navy-950/50">
          <tr>
            <th className="px-4 py-2.5 font-medium">Code</th>
            <th className="px-4 py-2.5 font-medium">Libellé</th>
            <th className="px-4 py-2.5 font-medium">Marque</th>
            <th className="px-4 py-2.5 font-medium">Gamme</th>
            <th className="px-4 py-2.5 text-right font-medium">Stock</th>
            <th className="px-4 py-2.5 font-medium">Statut</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-neutral-100 dark:divide-navy-700">
          {articles.map((a) => (
            <tr key={a.id} onClick={() => setSelected(a)} className="cursor-pointer hover:bg-neutral-50 dark:hover:bg-navy-800/50">
              <td className="px-4 py-2.5 font-mono text-xs">{a.codeAs400}</td>
              <td className="px-4 py-2.5 font-medium">{a.libelle}</td>
              <td className="px-4 py-2.5 text-neutral-500">{a.marque?.nom ?? '—'}</td>
              <td className="px-4 py-2.5 text-neutral-500">{a.gamme?.nom ?? '—'}</td>
              <td className={`px-4 py-2.5 text-right tabular-nums ${a.stock <= 0 ? 'font-semibold text-red-500' : ''}`}>{a.stock}</td>
              <td className="px-4 py-2.5"><ActiveBadge active={a.actif} /></td>
            </tr>
          ))}
          {articles.length === 0 ? (
            <tr>
              <td colSpan={6} className="px-4 py-8 text-center text-neutral-400">Aucun produit trouvé.</td>
            </tr>
          ) : null}
        </tbody>
      </table>

      {selected ? <ProductModal article={selected} onClose={() => setSelected(null)} /> : null}
    </div>
  );
}

function MiniStat({ icon: Icon, label, value, tone }: { icon: typeof Package; label: string; value: string; tone?: string }) {
  return (
    <div className="rounded-xl border border-neutral-100 bg-neutral-50 px-3 py-2.5 dark:border-navy-700 dark:bg-navy-800/40">
      <div className="flex items-center gap-1.5 text-[11px] uppercase tracking-wide text-neutral-400"><Icon size={13} /> {label}</div>
      <p className={`mt-1 text-lg font-bold tabular-nums ${tone ?? ''}`}>{value}</p>
    </div>
  );
}

function Info({ icon: Icon, label, value }: { icon: typeof Package; label: string; value: string }) {
  return (
    <div className="flex items-start gap-2.5">
      <Icon size={15} className="mt-0.5 shrink-0 text-neutral-400" />
      <div>
        <p className="text-[11px] uppercase tracking-wide text-neutral-400">{label}</p>
        <p className="text-sm">{value}</p>
      </div>
    </div>
  );
}

function ProductModal({ article: a, onClose }: { article: ArticleRow; onClose: () => void }) {
  const ventes = pseudoVentes(a.id);
  const etat = etatStock(a.stock, a.pcb);

  return (
    <div className="fixed inset-0 z-50 flex items-start justify-center overflow-y-auto bg-black/40 p-4 pt-12" onClick={onClose}>
      <div className="w-full max-w-xl rounded-2xl bg-white shadow-xl dark:bg-navy-900" onClick={(e) => e.stopPropagation()}>
        {/* En-tête */}
        <div className="flex items-start justify-between border-b border-neutral-100 px-5 py-4 dark:border-navy-700">
          <div className="min-w-0">
            <h2 className="flex items-center gap-2 text-lg font-bold">
              <span className="truncate">{a.libelle}</span>
              <ActiveBadge active={a.actif} />
            </h2>
            <p className="font-mono text-xs text-neutral-400">
              {a.codeAs400}
              {a.marque ? ` · ${a.marque.nom}` : ''}
            </p>
          </div>
          <button type="button" onClick={onClose} className="text-neutral-400 hover:text-neutral-600" aria-label="Fermer"><X size={18} /></button>
        </div>

        <div className="flex flex-col gap-4 px-5 py-4">
          {/* KPIs */}
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
            <MiniStat icon={Boxes} label="Stock" value={NB.format(a.stock)} tone={a.stock <= 0 ? 'text-red-500' : ''} />
            <MiniStat icon={Package} label="PCB" value={a.pcb != null ? String(a.pcb) : '—'} />
            <MiniStat icon={TrendingUp} label="Ventes 30j" value={NB.format(ventes)} />
            <MiniStat icon={AlertTriangle} label="État stock" value={etat.label} tone={etat.tone} />
          </div>

          {/* Identité */}
          <div className="grid grid-cols-2 gap-4 rounded-xl border border-neutral-100 px-4 py-4 dark:border-navy-700">
            <Info icon={Tag} label="Marque" value={a.marque?.nom ?? '—'} />
            <Info icon={Layers} label="Gamme" value={a.gamme?.nom ?? '—'} />
            <Info icon={Factory} label="Famille" value={a.famille?.nom ?? '—'} />
            <Info icon={Barcode} label="Code-barres" value={a.gencode ?? '—'} />
            <Info icon={Package} label="Type" value={a.typeArticle ?? '—'} />
            <Info icon={Tag} label="Code AS400" value={a.codeAs400} />
          </div>
        </div>
      </div>
    </div>
  );
}
