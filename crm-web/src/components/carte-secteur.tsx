'use client';

import { useEffect, useRef, useState } from 'react';
import type { Map as LeafletMap, LayerGroup } from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { Sprout, Store } from 'lucide-react';
import { geoloc } from '@/lib/geo';
import type { MagasinGeoPoint, ProspectRow } from '@/lib/api';

/**
 * Carte du secteur / de la région : magasins gérés (couleur de marque de l'espace, marqueur plein) et
 * prospects pas encore travaillés (couleur d'accent de l'espace, marqueur plus grand à contour pointillé), avec
 * filtres d'affichage par type.
 * Positions approximatives (ville / code postal) tant que les fiches n'ont pas de GPS.
 *
 * Couleurs : les marqueurs sont dessinés par Leaflet (canvas), qui ne connaît pas les classes Tailwind. Leur
 * couleur est lue sur les jetons du thème (`--espace-brand`, `--espace-accent`, posés par `data-espace`) au montage
 * de la carte : elle suit donc l'espace, comme les puces de filtre. Seules restent EN DUR (documentées ici) :
 *  - `REPLI_MARQUE` / `REPLI_ACCENT` : valeurs de secours si le jeton est illisible (violet de l'espace direction) ;
 *  - `#e5e7eb` : fond neutre de la pastille de classe dans les infobulles (HTML injecté, hors du thème) ;
 *  - les teintes des tuiles OpenStreetMap, qui ne dépendent pas de nous.
 * Le seul signe qui distingue un prospect d'un client dans l'espace promoteurs (marque et accent identiques) est
 * donc la forme du marqueur (taille et pointillé), en plus de la légende des puces.
 */
const REPLI_MARQUE = '#7656b8';
const REPLI_ACCENT = '#a98ae9';

/** Valeur d'un jeton CSS du thème, lue sur un élément de la carte ; `repli` si elle est absente. */
function jeton(el: HTMLElement, nom: string, repli: string): string {
  return getComputedStyle(el).getPropertyValue(nom).trim() || repli;
}

/** Échappe le HTML des données insérées dans les infobulles Leaflet. */
function esc(v: string | null | undefined): string {
  return (v ?? '').replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);
}

export function CarteSecteur({
  points,
  prospects,
}: {
  points: MagasinGeoPoint[];
  prospects: ProspectRow[];
}) {
  const containerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<LeafletMap | null>(null);
  const clientsLayer = useRef<LayerGroup | null>(null);
  const prospectsLayer = useRef<LayerGroup | null>(null);
  const [showClients, setShowClients] = useState(true);
  const [showProspects, setShowProspects] = useState(true);

  // Initialisation de la carte (client uniquement).
  useEffect(() => {
    let cancelled = false;
    (async () => {
      const L = (await import('leaflet')).default;
      if (cancelled || !containerRef.current || mapRef.current) return;

      // preferCanvas : indispensable pour dessiner ~12 000 marqueurs sans figer le navigateur.
      const map = L.map(containerRef.current, { scrollWheelZoom: true, preferCanvas: true }).setView([46.6, 2.4], 6);
      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom: 18,
        attribution: '&copy; OpenStreetMap',
      }).addTo(map);

      // Couleurs du thème de l'espace courant (voir l'en-tête du fichier).
      const couleurClients = jeton(containerRef.current, '--espace-brand', REPLI_MARQUE);
      const couleurProspects = jeton(containerRef.current, '--espace-accent', REPLI_ACCENT);

      const clients = L.layerGroup().addTo(map);
      const prospectsLg = L.layerGroup().addTo(map);
      const bounds: [number, number][] = [];

      for (const m of points) {
        // Coordonnées exactes (géocodage BAN) en priorité ; repli ville / département sinon.
        const pos =
          m.latitude != null && m.longitude != null
            ? { lat: m.latitude, lng: m.longitude, approx: false }
            : geoloc(m.id, m.ville, m.codePostal);
        if (!pos) continue;
        bounds.push([pos.lat, pos.lng]);
        L.circleMarker([pos.lat, pos.lng], {
          radius: 5,
          color: couleurClients,
          fillColor: couleurClients,
          fillOpacity: 0.7,
          weight: 1,
        })
          .bindPopup(
            `<b>${esc(m.enseigne)}</b> ${m.niveauClass ? `<span style="background:#e5e7eb;border-radius:9999px;padding:0 6px;font-weight:700">${esc(m.niveauClass)}</span>` : ''}<br/>` +
              `${esc([m.codePostal, m.ville].filter(Boolean).join(' '))}<br/>` +
              `Client géré${pos.approx ? ' · <i>position approximative</i>' : ''}<br/>` +
              `<a href="/clients/${encodeURIComponent(m.id)}">Ouvrir la fiche</a>`,
          )
          .addTo(clients);
      }

      for (const p of prospects) {
        const pos =
          p.latitude != null && p.longitude != null
            ? { lat: p.latitude, lng: p.longitude, approx: false }
            : geoloc(p.id, p.ville, p.codePostal);
        if (!pos) continue;
        bounds.push([pos.lat, pos.lng]);
        L.circleMarker([pos.lat, pos.lng], {
          radius: 8,
          color: couleurProspects,
          fillColor: couleurProspects,
          fillOpacity: 0.7,
          weight: 2,
          dashArray: '3 3',
        })
          .bindPopup(
            `<b>${esc(p.enseigne)}</b> ${p.niveauClass ? `<span style="background:#e5e7eb;border-radius:9999px;padding:0 6px;font-weight:700">${esc(p.niveauClass)}</span>` : ''}<br/>` +
              `${esc([p.codePostal, p.ville].filter(Boolean).join(' '))}<br/>` +
              `Prospect — pas encore client${p.assignedTo ? ` · ${esc(p.assignedTo.displayName)}` : ''}${pos.approx ? '<br/><i>position approximative (département)</i>' : ''}<br/>` +
              `<a href="/prospects/${encodeURIComponent(p.id)}">Ouvrir la fiche prospect</a>`,
          )
          .addTo(prospectsLg);
      }

      if (bounds.length > 0 && bounds.length <= 300) map.fitBounds(bounds, { padding: [40, 40], maxZoom: 11 });

      mapRef.current = map;
      clientsLayer.current = clients;
      prospectsLayer.current = prospectsLg;
    })();
    return () => {
      cancelled = true;
      mapRef.current?.remove();
      mapRef.current = null;
    };
    // Les données sont figées au montage (rendu serveur en amont).
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Filtres afficher / cacher.
  useEffect(() => {
    const map = mapRef.current;
    const layer = clientsLayer.current;
    if (!map || !layer) return;
    if (showClients) layer.addTo(map);
    else map.removeLayer(layer);
  }, [showClients]);
  useEffect(() => {
    const map = mapRef.current;
    const layer = prospectsLayer.current;
    if (!map || !layer) return;
    if (showProspects) layer.addTo(map);
    else map.removeLayer(layer);
  }, [showProspects]);

  // `tone` : bordure, fond ET couleur du texte de la puce active (jetons du thème : brand pour les clients, accent pour les prospects).
  const chip = (active: boolean, tone: string) =>
    `inline-flex items-center gap-1.5 rounded-full border px-3 py-1.5 text-xs font-semibold transition focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand ${
      active ? tone : 'border-neutral-200 bg-white text-neutral-500 dark:border-navy-700 dark:bg-navy-900 dark:text-neutral-400'
    }`;

  return (
    <div className="flex flex-col gap-2.5">
      {/* Filtres de calques */}
      <div className="flex flex-wrap items-center gap-2">
        <button
          type="button"
          onClick={() => setShowClients((v) => !v)}
          className={chip(showClients, 'border-brand bg-brand text-white')}
          aria-pressed={showClients}
        >
          <Store size={13} /> Mes clients ({points.length})
        </button>
        <button
          type="button"
          onClick={() => setShowProspects((v) => !v)}
          className={chip(showProspects, 'border-accent bg-accent text-navy-950')}
          aria-pressed={showProspects}
        >
          <Sprout size={13} /> Prospects ({prospects.length})
        </button>
      </div>

      {/* Carte */}
      <div
        ref={containerRef}
        className="z-0 h-[560px] w-full overflow-hidden rounded-2xl shadow-card"
        role="application"
        aria-label="Carte du secteur : clients gérés et prospects"
      />
    </div>
  );
}
