'use client';

import { useEffect, useRef, useState } from 'react';
import {
  ArrowLeft,
  Download,
  FileText,
  Package,
  RotateCcw,
  RotateCw,
  Maximize,
  X,
  ZoomIn,
  ZoomOut,
} from 'lucide-react';
import type { Bordereau } from './rappels-board';

/** Ligne produit d'un bordereau de retour. */
type LigneRappel = {
  libelle: string;
  lot: string;
  ean: string;
  codeMinos: string;
  refArticle: string;
  qte: number;
  action: 'absent' | 'repris' | 'détruit';
};

const PRODUITS_RAPPEL = [
  { libelle: 'DIS - FLEUR DE DOUCHE ARIEL', ean: '3666085407454', codeMinos: '963691', ref: '40745' },
  { libelle: 'DIS - FLEUR DE DOUCHE STITCH', ean: '3666085407522', codeMinos: '963692', ref: '40752' },
  { libelle: 'DIS - FLEUR DE DOUCHE CARS', ean: '3666085407843', codeMinos: '963693', ref: '40784' },
  { libelle: 'DIS - FLEUR DE DOUCHE BARBIE', ean: '3666085850325', codeMinos: '963694', ref: '85032' },
  { libelle: 'DIS - COFFRET DE BAIN CARS', ean: '3666085950479', codeMinos: '963701', ref: '95047' },
  { libelle: 'DIS - COFFRET DE BAIN WISH', ean: '3666085950547', codeMinos: '963702', ref: '95054' },
  { libelle: 'DIS - COFFRET DE BAIN STITCH', ean: '3666085950103', codeMinos: '963703', ref: '95010' },
  { libelle: 'DIS - COFFRET DE BAIN ARIEL', ean: '3666085958116', codeMinos: '963704', ref: '95811' },
  { libelle: 'DIS - COFFRET DE BAIN SHEA', ean: '3666085951165', codeMinos: '963705', ref: '95116' },
  { libelle: 'DIS - COFFRET DE BAIN BARBIE', ean: '3666085910666', codeMinos: '963706', ref: '91066' },
  { libelle: 'DIS - FDD SIMBA', ean: '3666085360755', codeMinos: '963707', ref: '36075' },
];

/** RNG déterministe par bordereau : mêmes lignes à chaque affichage. */
function lignesDuBordereau(b: Bordereau): LigneRappel[] {
  let seed = [...b.numero].reduce((a, c) => (a * 31 + c.charCodeAt(0)) | 0, 7);
  const rand = () => {
    seed |= 0; seed = (seed + 0x6d2b79f5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  return Array.from({ length: b.lignes }, (_, i) => {
    const p = PRODUITS_RAPPEL[i % PRODUITS_RAPPEL.length];
    const qte = rand() < 0.55 ? 0 : Math.floor(rand() * 5) + 1;
    return {
      libelle: p.libelle,
      lot: String(21000 + Math.floor(rand() * 900)),
      ean: p.ean,
      codeMinos: p.codeMinos,
      refArticle: p.ref,
      qte,
      action: qte === 0 ? 'absent' : rand() < 0.5 ? 'repris' : 'détruit',
    };
  });
}

const ACTION_BADGE: Record<LigneRappel['action'], string> = {
  absent: 'bg-amber-400/20 text-amber-700 dark:text-amber-400',
  repris: 'bg-emerald-500/15 text-emerald-700 dark:text-emerald-400',
  détruit: 'bg-red-500/12 text-red-600 dark:text-red-400',
};

const DATE_FMT = new Intl.DateTimeFormat('fr-FR', {
  year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit',
});

/** Visionneuse plein écran : zoom (molette / boutons), rotation 90°, déplacement à la souris. */
function PhotoViewer({ src, alt, onClose }: { src: string; alt: string; onClose: () => void }) {
  const [zoom, setZoom] = useState(1);
  const [rotation, setRotation] = useState(0);
  const [pos, setPos] = useState({ x: 0, y: 0 });
  const drag = useRef<{ x: number; y: number; px: number; py: number } | null>(null);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    document.addEventListener('keydown', onKey);
    document.body.style.overflow = 'hidden';
    return () => {
      document.removeEventListener('keydown', onKey);
      document.body.style.overflow = '';
    };
  }, [onClose]);

  const reset = () => { setZoom(1); setRotation(0); setPos({ x: 0, y: 0 }); };
  const bump = (d: number) => setZoom((z) => Math.min(6, Math.max(0.4, Math.round((z + d) * 10) / 10)));

  const btn =
    'rounded-lg bg-white/10 p-2.5 text-white transition hover:bg-white/25 focus:outline-none focus:ring-2 focus:ring-white/40';

  return (
    <div
      className="fixed inset-0 z-[90] flex flex-col bg-black/90"
      role="dialog"
      aria-modal="true"
      aria-label="Photo du bordereau"
      onWheel={(e) => bump(e.deltaY < 0 ? 0.2 : -0.2)}
    >
      {/* Barre d'outils */}
      <div className="flex items-center gap-1.5 p-3">
        <span className="mr-auto rounded-lg bg-white/10 px-3 py-1.5 text-xs font-medium text-white/90">
          {alt} · {Math.round(zoom * 100)} %
        </span>
        <button type="button" onClick={() => bump(0.4)} className={btn} title="Zoomer" aria-label="Zoomer"><ZoomIn size={18} /></button>
        <button type="button" onClick={() => bump(-0.4)} className={btn} title="Dézoomer" aria-label="Dézoomer"><ZoomOut size={18} /></button>
        <button type="button" onClick={() => setRotation((r) => r - 90)} className={btn} title="Pivoter à gauche" aria-label="Pivoter à gauche"><RotateCcw size={18} /></button>
        <button type="button" onClick={() => setRotation((r) => r + 90)} className={btn} title="Pivoter à droite" aria-label="Pivoter à droite"><RotateCw size={18} /></button>
        <button type="button" onClick={reset} className={btn} title="Réinitialiser la vue" aria-label="Réinitialiser la vue"><Maximize size={18} /></button>
        <button type="button" onClick={onClose} className={btn} title="Fermer (Échap)" aria-label="Fermer"><X size={18} /></button>
      </div>

      {/* Image (déplaçable à la souris) */}
      <div
        className="flex flex-1 items-center justify-center overflow-hidden"
        style={{ cursor: drag.current ? 'grabbing' : 'grab', touchAction: 'none' }}
        onPointerDown={(e) => {
          (e.target as Element).setPointerCapture?.(e.pointerId);
          drag.current = { x: e.clientX, y: e.clientY, px: pos.x, py: pos.y };
        }}
        onPointerMove={(e) => {
          if (!drag.current) return;
          setPos({ x: drag.current.px + e.clientX - drag.current.x, y: drag.current.py + e.clientY - drag.current.y });
        }}
        onPointerUp={() => { drag.current = null; }}
        onPointerCancel={() => { drag.current = null; }}
      >
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={src}
          alt={alt}
          draggable={false}
          className="max-h-[85vh] max-w-[90vw] select-none transition-transform duration-100"
          style={{ transform: `translate(${pos.x}px, ${pos.y}px) scale(${zoom}) rotate(${rotation}deg)` }}
        />
      </div>
    </div>
  );
}

/** Fiche détaillée d'un bordereau de retour : infos, photo (visionneuse) et lignes produits. */
export function RappelDetail({ bordereau, onRetour }: { bordereau: Bordereau; onRetour: () => void }) {
  const [viewer, setViewer] = useState(false);
  const lignes = lignesDuBordereau(bordereau);

  const exportCsv = () => {
    const header = ['Libellé produit', 'N° lot', 'Code EAN', 'Code produit Minos', 'Ref article', 'Qté', 'Action'];
    const rows = lignes.map((l) => [l.libelle, l.lot, l.ean, l.codeMinos, l.refArticle, String(l.qte), l.action]);
    const csv = [header, ...rows].map((r) => r.map((c) => `"${c.replace(/"/g, '""')}"`).join(';')).join('\n');
    const blob = new Blob(['﻿' + csv], { type: 'text/csv;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `${bordereau.numero}.csv`;
    link.click();
    URL.revokeObjectURL(url);
  };

  // « Conversion PDF » : fenêtre imprimable (le navigateur propose Enregistrer en PDF).
  const convertirPdf = () => {
    const w = window.open('', '_blank', 'width=900,height=1100');
    if (!w) return;
    const rows = lignes
      .map((l) => `<tr><td>${l.libelle}</td><td>${l.lot}</td><td>${l.ean}</td><td>${l.codeMinos}</td><td>${l.refArticle}</td><td style="text-align:right">${l.qte}</td><td>${l.action}</td></tr>`)
      .join('');
    w.document.write(`<!doctype html><html lang="fr"><head><meta charset="utf-8"><title>${bordereau.numero}</title>
      <style>body{font-family:system-ui,sans-serif;margin:32px;color:#222}h1{font-size:20px}dl{display:grid;grid-template-columns:140px 1fr;gap:4px 12px;font-size:13px}dt{font-weight:600}
      table{width:100%;border-collapse:collapse;margin-top:16px;font-size:12px}th,td{border:1px solid #ccc;padding:5px 8px;text-align:left}th{background:#f2f2f2}</style></head><body>
      <h1>Bordereau ${bordereau.numero} — ${bordereau.lignes} ligne(s)</h1>
      <dl><dt>Date retour</dt><dd>${DATE_FMT.format(new Date(bordereau.dateRetour))}</dd>
      <dt>Promoteur</dt><dd>${bordereau.promoteur}</dd>
      <dt>Magasin</dt><dd>${bordereau.codeMagasin} — ${bordereau.magasin}</dd></dl>
      <table><thead><tr><th>Libellé produit</th><th>N° lot</th><th>Code EAN</th><th>Code produit Minos</th><th>Ref article</th><th>Qté</th><th>Action</th></tr></thead>
      <tbody>${rows}</tbody></table></body></html>`);
    w.document.close();
    w.focus();
    w.print();
  };

  return (
    <div className="flex min-w-0 flex-col gap-4">
      {/* Barre d'en-tête */}
      <div className="flex flex-wrap items-center gap-2 rounded-2xl bg-white p-3 shadow-card">
        <Package size={18} className="shrink-0 text-brand dark:text-accent" />
        <h2 className="text-base font-bold">
          Bordereau <span className="font-mono text-brand dark:text-accent">{bordereau.numero}</span>
        </h2>
        <span className="rounded-full bg-neutral-100 px-2.5 py-0.5 text-xs font-semibold text-neutral-500 dark:bg-navy-800 dark:text-neutral-300">
          {bordereau.lignes} ligne{bordereau.lignes > 1 ? 's' : ''}
        </span>
        <div className="ml-auto flex flex-wrap items-center gap-2">
          <button
            type="button"
            onClick={exportCsv}
            className="inline-flex items-center gap-1.5 rounded-lg bg-emerald-600 px-3 py-1.5 text-xs font-semibold text-white transition hover:bg-emerald-700"
          >
            <Download size={13} /> Export CSV
          </button>
          <button
            type="button"
            onClick={convertirPdf}
            className="inline-flex items-center gap-1.5 rounded-lg bg-red-600 px-3 py-1.5 text-xs font-semibold text-white transition hover:bg-red-700"
          >
            <FileText size={13} /> Convertir en PDF
          </button>
          <button
            type="button"
            onClick={onRetour}
            className="inline-flex items-center gap-1.5 rounded-lg border border-neutral-200 px-3 py-1.5 text-xs font-medium text-neutral-600 transition hover:bg-neutral-100 dark:border-navy-700 dark:text-neutral-300 dark:hover:bg-navy-800"
          >
            <ArrowLeft size={13} /> Retour à la liste
          </button>
        </div>
      </div>

      {/* Infos + photo */}
      <div className="rounded-2xl bg-white p-5 shadow-card">
        <dl className="grid gap-x-6 gap-y-2 text-sm sm:grid-cols-[160px_minmax(0,1fr)]">
          <dt className="font-semibold">N° bordereau</dt>
          <dd className="font-mono">{bordereau.numero}</dd>
          <dt className="font-semibold">Date retour</dt>
          <dd>{DATE_FMT.format(new Date(bordereau.dateRetour))}</dd>
          <dt className="font-semibold">Promoteur</dt>
          <dd>{bordereau.promoteur}</dd>
          <dt className="font-semibold">Magasin</dt>
          <dd>{bordereau.codeMagasin} — {bordereau.magasin}</dd>
        </dl>

        <p className="mt-5 text-sm text-neutral-400">Photo du bordereau</p>
        <button
          type="button"
          onClick={() => setViewer(true)}
          className="group mt-2 overflow-hidden rounded-xl border border-neutral-200 transition hover:border-brand focus:outline-none focus:ring-2 focus:ring-brand/50 dark:border-navy-700 dark:hover:border-accent"
          title="Agrandir la photo (zoom, rotation…)"
        >
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src="/demo-bordereau.svg"
            alt={`Photo du bordereau ${bordereau.numero}`}
            className="h-64 w-auto transition group-hover:scale-[1.03]"
          />
        </button>
      </div>

      {/* Lignes produits */}
      <div>
        <p className="mb-2 text-sm text-neutral-400">Produits</p>
        <div className="overflow-x-auto rounded-2xl bg-white shadow-card">
          <table className="w-full min-w-[820px] text-sm">
            <thead className="border-b border-neutral-100 text-left text-[11px] uppercase tracking-wider text-neutral-400 dark:border-navy-700">
              <tr>
                <th className="px-4 py-2.5 font-medium">Libellé produit</th>
                <th className="px-4 py-2.5 font-medium">N° lot</th>
                <th className="px-4 py-2.5 font-medium">Code EAN</th>
                <th className="px-4 py-2.5 font-medium">Code produit Minos</th>
                <th className="px-4 py-2.5 font-medium">Ref article</th>
                <th className="px-4 py-2.5 text-right font-medium">Qté</th>
                <th className="px-4 py-2.5 font-medium">Action</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-neutral-100 dark:divide-navy-700">
              {lignes.map((l, i) => (
                <tr key={i} className="hover:bg-neutral-50 dark:hover:bg-navy-800/50">
                  <td className="px-4 py-2.5">{l.libelle}</td>
                  <td className="px-4 py-2.5 font-mono text-xs">{l.lot}</td>
                  <td className="px-4 py-2.5 font-mono text-xs">{l.ean}</td>
                  <td className="px-4 py-2.5 font-mono text-xs">{l.codeMinos}</td>
                  <td className="px-4 py-2.5 font-mono text-xs">{l.refArticle}</td>
                  <td className="px-4 py-2.5 text-right tabular-nums">{l.qte}</td>
                  <td className="px-4 py-2.5">
                    <span className={`rounded-md px-2 py-0.5 text-xs font-semibold ${ACTION_BADGE[l.action]}`}>{l.action}</span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {viewer ? (
        <PhotoViewer
          src="/demo-bordereau.svg"
          alt={`Bordereau ${bordereau.numero}`}
          onClose={() => setViewer(false)}
        />
      ) : null}
    </div>
  );
}
