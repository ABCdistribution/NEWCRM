'use client';

import { useEffect, useRef } from 'react';
import Link from 'next/link';
import type { Map as LeafletMap } from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { ArrowRight, MapPinned } from 'lucide-react';

export type RegionVisites = { code: string; nom: string; ville: string; lat: number; lng: number; visites: number };

const BLEU = '#3B82F6';
const ECHELLE_FRANCE: [[number, number], [number, number]] = [
  [41.3, -5.2],
  [51.2, 9.6],
];

const esc = (t: string) => t.replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);

/**
 * Répartition des visites du mois par région : carte de France (une bulle par région, au chef-lieu,
 * dont la taille suit le nombre de visites) et classement des premières régions.
 */
export function RepartitionVisites({
  regions,
  total,
  moisLabel,
}: {
  regions: RegionVisites[];
  total: number;
  moisLabel: string;
}) {
  const conteneur = useRef<HTMLDivElement>(null);
  const carte = useRef<LeafletMap | null>(null);
  const max = Math.max(1, ...regions.map((r) => r.visites));

  useEffect(() => {
    if (regions.length === 0) return;
    let annule = false;
    let observateur: ResizeObserver | null = null;
    (async () => {
      const L = (await import('leaflet')).default;
      if (annule || !conteneur.current || carte.current) return;

      // Carte figée (aperçu) : pas de zoom ni de déplacement.
      const map = L.map(conteneur.current, {
        zoomControl: false,
        dragging: false,
        scrollWheelZoom: false,
        doubleClickZoom: false,
        touchZoom: false,
        boxZoom: false,
        keyboard: false,
        attributionControl: true,
      });
      // Fond OpenStreetMap, désaturé et éclairci pour rester discret derrière les bulles.
      L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom: 18,
        attribution: '&copy; OpenStreetMap',
      }).addTo(map);
      const fond = map.getPane('tilePane');
      if (fond) fond.style.filter = 'grayscale(1) contrast(0.85) brightness(1.1) opacity(0.55)';
      map.fitBounds(ECHELLE_FRANCE);

      for (const r of regions) {
        const taille = Math.round(28 + (r.visites / max) * 16);
        L.marker([r.lat, r.lng], {
          interactive: false,
          icon: L.divIcon({
            className: '',
            iconSize: [0, 0],
            html:
              `<div style="position:absolute;display:flex;align-items:center;gap:5px;transform:translate(-${taille / 2}px,-${taille / 2}px);white-space:nowrap">` +
              `<span style="display:inline-flex;align-items:center;justify-content:center;width:${taille}px;height:${taille}px;border-radius:9999px;background:${BLEU};color:#fff;font:700 13px system-ui,sans-serif;border:2px solid #fff;box-shadow:0 1px 4px rgba(30,64,175,.45)">${r.visites}</span>` +
              `<span style="font:600 11px system-ui,sans-serif;color:#334155;text-shadow:0 0 3px #fff,0 0 3px #fff">${esc(r.ville)}</span>` +
              `</div>`,
          }),
        }).addTo(map);
      }
      carte.current = map;
      observateur = new ResizeObserver(() => {
        map.invalidateSize();
        map.fitBounds(ECHELLE_FRANCE);
      });
      observateur.observe(conteneur.current);
    })();
    return () => {
      annule = true;
      observateur?.disconnect();
      carte.current?.remove();
      carte.current = null;
    };
  }, [regions, max]);

  return (
    <section className="h-full rounded-2xl bg-white shadow-card">
      <div className="flex items-center gap-2 px-5 pt-4">
        <MapPinned size={18} className="text-blue-500" aria-hidden />
        <h2 className="text-sm font-semibold">Répartition des visites</h2>
        <span className="ml-auto rounded-lg border border-neutral-200 px-3 py-1.5 text-sm font-medium">{moisLabel}</span>
      </div>

      {regions.length === 0 ? (
        <p className="px-5 py-20 text-center text-sm text-neutral-400">
          Aucune visite localisée sur {moisLabel.toLowerCase()}.
        </p>
      ) : (
        <div className="grid grid-cols-1 gap-4 p-5 sm:grid-cols-5">
          <div ref={conteneur} className="isolate h-64 overflow-hidden rounded-xl bg-blue-50 sm:col-span-3 sm:h-72" />
          <div className="flex flex-col sm:col-span-2">
            <h3 className="mb-2 text-sm font-semibold">Top régions (visites)</h3>
            <ul className="divide-y divide-neutral-100 text-sm">
              {regions.slice(0, 5).map((r) => (
                <li key={r.code} className="flex items-center justify-between gap-3 py-2">
                  <span className="min-w-0 truncate" title={r.nom}>
                    {r.nom}
                  </span>
                  <span className="font-semibold tabular-nums">{r.visites}</span>
                </li>
              ))}
            </ul>
            <p className="mt-2 text-xs text-neutral-400">{total} visite{total > 1 ? 's' : ''} au total</p>
            <Link href="/visites" className="mt-auto inline-flex items-center gap-1 pt-3 text-sm font-medium text-blue-600 hover:underline">
              Voir toutes les visites <ArrowRight size={14} aria-hidden />
            </Link>
          </div>
        </div>
      )}
    </section>
  );
}
