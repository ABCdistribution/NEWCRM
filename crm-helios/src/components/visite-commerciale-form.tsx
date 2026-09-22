'use client';

import { useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { Check, ClipboardCheck, X } from 'lucide-react';
import { saveVisiteCommerciale } from '@/lib/magasin-actions';

/** Checklist de la visite commerciale (reprise de l'outil historique). */
const QUESTIONS = [
  'Validation répartition linéaire',
  'Validation assortiment',
  'Respect PVC et balisage correspondant',
  'Ruptures',
  'Balisage',
];

const OBJETS = ['Bilan activité', 'Dynamique promotionnelle', 'Nouveautés / lancements', 'Négociation / référencement'];
const REMPLISSAGES = ['Vide', 'Faible', 'Moitié', 'Bien rempli', 'Plein'];

type Reponse = { ok: boolean | null; remarque: string };

/**
 * Questionnaire de visite commerciale d'un magasin : RDV, objets, checklist
 * ✓/✗ avec remarque, remplissage du linéaire, compte rendu et prochaine visite.
 */
export function VisiteCommercialeForm({ clientId, enseigne }: { clientId: string; enseigne: string }) {
  const router = useRouter();
  const [avecRdv, setAvecRdv] = useState(false);
  const [objets, setObjets] = useState<string[]>([]);
  const [reponses, setReponses] = useState<Record<string, Reponse>>(
    Object.fromEntries(QUESTIONS.map((q) => [q, { ok: null, remarque: '' }])),
  );
  const [remplissage, setRemplissage] = useState('Moitié');
  const [compteRendu, setCompteRendu] = useState('');
  const [prochaineVisite, setProchaineVisite] = useState('');
  const [erreur, setErreur] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  const setOk = (q: string, ok: boolean) =>
    setReponses((r) => ({ ...r, [q]: { ...r[q], ok: r[q].ok === ok ? null : ok } }));

  const enregistrer = () => {
    startTransition(async () => {
      const { error } = await saveVisiteCommerciale(clientId, {
        avecRdv,
        objets,
        remplissage,
        compteRendu,
        prochaineVisite: prochaineVisite || undefined,
        reponses: QUESTIONS.filter((q) => reponses[q].ok !== null).map((q) => ({
          libelle: q,
          ok: reponses[q].ok!,
          remarque: reponses[q].remarque || undefined,
        })),
      });
      if (error) setErreur(error);
      else router.push(`/pilotage/magasins?visite=ok`);
    });
  };

  const boutonToggle = (actif: boolean, couleur: 'vert' | 'rouge') =>
    `rounded-lg border px-2.5 py-1.5 transition ${
      actif
        ? couleur === 'vert'
          ? 'border-emerald-500 bg-emerald-50 text-emerald-600 dark:bg-emerald-950/40'
          : 'border-red-500 bg-red-50 text-red-600 dark:bg-red-950/40'
        : 'border-neutral-200 text-neutral-400 hover:border-neutral-300 dark:border-navy-700'
    }`;

  return (
    <div className="flex flex-col gap-5">
      {/* Contexte de la visite */}
      <section className="rounded-2xl bg-white p-5 shadow-card">
        <h2 className="mb-3 text-sm font-semibold">Contexte</h2>
        <label className="flex w-fit cursor-pointer items-center gap-2 text-sm">
          <input type="checkbox" checked={avecRdv} onChange={(e) => setAvecRdv(e.target.checked)} className="h-4 w-4 accent-[var(--color-brand)]" />
          Visite avec RDV
        </label>
        <p className="mb-1.5 mt-4 text-xs font-medium text-neutral-500">Objet de la visite</p>
        <div className="flex flex-wrap gap-2">
          {OBJETS.map((o) => {
            const actif = objets.includes(o);
            return (
              <button
                key={o}
                type="button"
                onClick={() => setObjets((cur) => (actif ? cur.filter((x) => x !== o) : [...cur, o]))}
                className={`rounded-full border px-3 py-1.5 text-xs font-medium transition ${
                  actif
                    ? 'border-brand bg-brand text-white dark:border-accent dark:bg-accent dark:text-brand'
                    : 'border-neutral-200 text-neutral-500 hover:border-neutral-300 dark:border-navy-700'
                }`}
              >
                {o}
              </button>
            );
          })}
        </div>
      </section>

      {/* Checklist */}
      <section className="rounded-2xl bg-white p-5 shadow-card">
        <h2 className="mb-3 text-sm font-semibold">Points de contrôle</h2>
        <ul className="divide-y divide-neutral-100 dark:divide-navy-700">
          {QUESTIONS.map((q) => {
            const r = reponses[q];
            return (
              <li key={q} className="flex flex-col gap-2 py-3 sm:flex-row sm:items-center sm:justify-between">
                <p className="text-sm font-medium">{q}</p>
                <div className="flex items-center gap-2">
                  <input
                    type="text"
                    placeholder="Remarque…"
                    value={r.remarque}
                    onChange={(e) => setReponses((cur) => ({ ...cur, [q]: { ...cur[q], remarque: e.target.value } }))}
                    className="w-48 rounded-lg border border-neutral-200 px-2.5 py-1.5 text-xs outline-none focus:border-brand dark:border-navy-700 dark:bg-navy-950"
                  />
                  <button type="button" onClick={() => setOk(q, true)} aria-label={`${q} : conforme`} className={boutonToggle(r.ok === true, 'vert')}>
                    <Check size={15} />
                  </button>
                  <button type="button" onClick={() => setOk(q, false)} aria-label={`${q} : non conforme`} className={boutonToggle(r.ok === false, 'rouge')}>
                    <X size={15} />
                  </button>
                </div>
              </li>
            );
          })}
        </ul>
        <div className="mt-3 flex flex-wrap items-center gap-3 border-t border-neutral-100 pt-4 dark:border-navy-700">
          <p className="text-sm font-medium">Point Gestion Linéaire — remplissage</p>
          <select
            value={remplissage}
            onChange={(e) => setRemplissage(e.target.value)}
            className="rounded-lg border border-neutral-200 px-2.5 py-1.5 text-sm outline-none focus:border-brand dark:border-navy-700 dark:bg-navy-950"
          >
            {REMPLISSAGES.map((r) => (
              <option key={r}>{r}</option>
            ))}
          </select>
        </div>
      </section>

      {/* Compte rendu + prochaine visite */}
      <section className="rounded-2xl bg-white p-5 shadow-card">
        <h2 className="mb-3 text-sm font-semibold">Compte rendu</h2>
        <textarea
          value={compteRendu}
          onChange={(e) => setCompteRendu(e.target.value)}
          rows={4}
          placeholder={`Synthèse de la visite chez ${enseigne}…`}
          className="w-full rounded-xl border border-neutral-200 px-3 py-2.5 text-sm outline-none focus:border-brand dark:border-navy-700 dark:bg-navy-950"
        />
        <div className="mt-3 flex items-center gap-2">
          <label className="text-sm font-medium" htmlFor="prochaine">Prochaine visite</label>
          <input
            id="prochaine"
            type="date"
            value={prochaineVisite}
            min={new Date().toISOString().slice(0, 10)}
            onChange={(e) => setProchaineVisite(e.target.value)}
            className="rounded-lg border border-neutral-200 px-2.5 py-1.5 text-sm outline-none focus:border-brand dark:border-navy-700 dark:bg-navy-950"
          />
        </div>
      </section>

      {erreur ? <p className="text-sm text-red-500">{erreur}</p> : null}
      <div className="flex justify-end">
        <button
          type="button"
          onClick={enregistrer}
          disabled={pending}
          className="inline-flex items-center gap-2 rounded-xl bg-brand px-5 py-2.5 text-sm font-semibold text-white transition hover:bg-brand/90 disabled:opacity-40 dark:bg-accent dark:text-brand dark:hover:bg-accent/80"
        >
          <ClipboardCheck size={16} /> Enregistrer la visite
        </button>
      </div>
    </div>
  );
}
