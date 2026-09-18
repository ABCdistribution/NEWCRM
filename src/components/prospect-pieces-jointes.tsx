'use client';

import { useRef, useState, useTransition } from 'react';
import { Download, FileText, Paperclip, Trash2 } from 'lucide-react';
import { uploadPieceJointe, deletePieceJointe, type PieceJointe } from '@/lib/prospect-actions';

const DT = new Intl.DateTimeFormat('fr-FR', { day: '2-digit', month: 'short', year: 'numeric' });

function tailleLisible(octets: number): string {
  if (octets >= 1024 * 1024) return `${(octets / 1024 / 1024).toFixed(1)} Mo`;
  if (octets >= 1024) return `${Math.round(octets / 1024)} Ko`;
  return `${octets} o`;
}

/**
 * Pièces jointes de la fiche prospect : dépôt (10 Mo max), téléchargement via
 * le relais authentifié /pj/…, suppression.
 */
export function ProspectPiecesJointes({ prospectId, pieces }: { prospectId: string; pieces: PieceJointe[] }) {
  const inputRef = useRef<HTMLInputElement>(null);
  const [erreur, setErreur] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  const deposer = (fichier: File) => {
    const fd = new FormData();
    fd.set('fichier', fichier);
    startTransition(async () => {
      const { error } = await uploadPieceJointe(prospectId, fd);
      setErreur(error);
      if (inputRef.current) inputRef.current.value = '';
    });
  };

  return (
    <div className="flex flex-col gap-2 px-5 py-4">
      {pieces.length === 0 ? (
        <p className="text-sm text-neutral-400">Aucune pièce jointe.</p>
      ) : (
        <ul className="flex flex-col gap-1.5">
          {pieces.map((pj) => (
            <li key={pj.id} className="group flex items-center gap-2.5 rounded-lg border border-neutral-100 px-3 py-2 dark:border-navy-700">
              <FileText size={15} className="shrink-0 text-[#7D8CCE]" />
              <div className="min-w-0 flex-1">
                <a
                  href={`/pj/${prospectId}/${pj.id}`}
                  className="block truncate text-sm font-medium hover:text-brand hover:underline dark:hover:text-accent"
                  title={`Télécharger ${pj.nom}`}
                >
                  {pj.nom}
                </a>
                <p className="text-[11px] text-neutral-400">
                  {tailleLisible(pj.taille)} · {DT.format(new Date(pj.createdAt))}
                  {pj.auteur ? ` · ${pj.auteur.displayName}` : ''}
                </p>
              </div>
              <a href={`/pj/${prospectId}/${pj.id}`} className="rounded p-1 text-neutral-400 transition hover:text-brand dark:hover:text-accent" aria-label={`Télécharger ${pj.nom}`}>
                <Download size={14} />
              </a>
              <button
                type="button"
                onClick={() => startTransition(async () => void (await deletePieceJointe(prospectId, pj.id)))}
                className="rounded p-1 text-neutral-400 opacity-0 transition hover:text-red-500 group-hover:opacity-100"
                aria-label={`Supprimer ${pj.nom}`}
              >
                <Trash2 size={14} />
              </button>
            </li>
          ))}
        </ul>
      )}

      <input
        ref={inputRef}
        type="file"
        className="hidden"
        onChange={(e) => {
          const f = e.target.files?.[0];
          if (f) deposer(f);
        }}
      />
      <button
        type="button"
        disabled={pending}
        onClick={() => inputRef.current?.click()}
        className="inline-flex w-fit items-center gap-1.5 rounded-lg border border-dashed border-neutral-300 px-3 py-1.5 text-xs font-medium text-neutral-500 transition hover:border-brand hover:text-brand disabled:opacity-40 dark:border-navy-600 dark:hover:border-accent dark:hover:text-accent"
      >
        <Paperclip size={13} /> {pending ? 'Envoi…' : 'Ajouter une pièce jointe'}
      </button>
      {erreur ? <p className="text-xs text-red-500">{erreur}</p> : null}
      <p className="text-[11px] text-neutral-400">PDF, images, documents — 10 Mo maximum.</p>
    </div>
  );
}
