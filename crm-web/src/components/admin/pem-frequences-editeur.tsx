'use client';

import { useState, useTransition } from 'react';
import { enregistrerFrequencesPem } from '@/lib/pem-actions';
import { SEMAINES_MAX, SEMAINES_MIN, libelleSemaines, semainesValides, type FrequencesPem } from '@/lib/pem';
import { ClassBadge } from '@/components/class-badge';

const FOCUS = 'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand/40';
const CHAMP = `w-20 rounded-lg border border-neutral-200 bg-white px-2.5 py-1.5 text-sm outline-none transition focus:border-brand ${FOCUS}`;

const enTexte = (f: FrequencesPem): Record<string, string> =>
  Object.fromEntries(f.classes.map((c) => [c.niveauClass, String(c.semaines)]));

/** Fréquence (en semaines) des visites PEM pour chacune des 7 classes ; « sans classe » en lecture seule. */
export function PemFrequencesEditeur({ frequences }: { frequences: FrequencesPem }) {
  const [valeurs, setValeurs] = useState(() => enTexte(frequences));
  const [erreur, setErreur] = useState<string | null>(null);
  const [enregistre, setEnregistre] = useState(false);
  const [enCours, demarrer] = useTransition();

  const invalides = frequences.classes.filter((c) => semainesValides(valeurs[c.niveauClass]) === null).map((c) => c.niveauClass);
  const modifie = frequences.classes.some((c) => valeurs[c.niveauClass]?.trim() !== String(c.semaines));

  const enregistrer = () => {
    const fd = new FormData();
    for (const c of frequences.classes) fd.set(`semaines-${c.niveauClass}`, valeurs[c.niveauClass] ?? '');
    demarrer(async () => {
      const message = await enregistrerFrequencesPem(fd);
      setErreur(message);
      setEnregistre(message === null);
    });
  };

  return (
    <form
      className="flex flex-col gap-3"
      onSubmit={(e) => {
        e.preventDefault();
        if (invalides.length === 0) enregistrer();
      }}
    >
      <div className="overflow-x-auto rounded-xl border border-neutral-200 bg-white">
        <table className="w-full min-w-[20rem] text-sm">
          <thead className="text-left text-xs text-neutral-500">
            <tr className="border-b border-neutral-100">
              <th scope="col" className="px-4 py-2 font-medium">
                Classe du magasin
              </th>
              <th scope="col" className="px-4 py-2 font-medium">
                Une visite PEM toutes les (semaines)
              </th>
            </tr>
          </thead>
          <tbody className="divide-y divide-neutral-100">
            {frequences.classes.map((c) => {
              const invalide = semainesValides(valeurs[c.niveauClass]) === null;
              return (
                <tr key={c.niveauClass}>
                  <th scope="row" className="px-4 py-2 text-left font-medium">
                    <span className="inline-flex items-center gap-2">
                      <ClassBadge value={c.niveauClass} size="md" />
                      Classe {c.niveauClass}
                    </span>
                  </th>
                  <td className="px-4 py-2">
                    <input
                      type="number"
                      inputMode="numeric"
                      min={SEMAINES_MIN}
                      max={SEMAINES_MAX}
                      step={1}
                      value={valeurs[c.niveauClass] ?? ''}
                      onChange={(e) => {
                        setValeurs((v) => ({ ...v, [c.niveauClass]: e.target.value }));
                        setEnregistre(false);
                      }}
                      aria-label={`Fréquence de la classe ${c.niveauClass}, en semaines`}
                      aria-invalid={invalide}
                      className={`${CHAMP} ${invalide ? 'border-red-400' : ''}`}
                    />
                  </td>
                </tr>
              );
            })}
            <tr className="bg-neutral-50 text-neutral-600">
              <th scope="row" className="px-4 py-2 text-left font-medium">
                Sans classe
              </th>
              <td className="px-4 py-2">{libelleSemaines(frequences.sansClasse)}</td>
            </tr>
          </tbody>
        </table>
      </div>

      <div className="flex flex-wrap items-center gap-3">
        <button
          type="submit"
          disabled={enCours || !modifie || invalides.length > 0}
          className={`inline-flex items-center rounded-xl bg-brand px-3 py-1.5 text-sm font-medium text-white transition hover:bg-brand/90 disabled:opacity-50 ${FOCUS}`}
        >
          {enCours ? 'Enregistrement…' : 'Enregistrer'}
        </button>
        <div aria-live="polite" className="text-xs">
          {invalides.length > 0 ? (
            <span className="text-red-600">
              Classe{invalides.length > 1 ? 's' : ''} {invalides.join(', ')} : un nombre entier de {SEMAINES_MIN} à {SEMAINES_MAX}.
            </span>
          ) : enregistre ? (
            <span className="text-emerald-700">Fréquences enregistrées.</span>
          ) : null}
        </div>
      </div>
      {erreur ? (
        <p role="alert" className="text-xs text-red-600">
          {erreur}
        </p>
      ) : null}
    </form>
  );
}
