import Link from 'next/link';
import { Sprout, TrendingUp } from 'lucide-react';

const EUR = new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR', maximumFractionDigits: 0 });

type Prospection = {
  ouverts: number;
  pipelinePondere: number;
  gagnes: number;
  potentielGagne: number;
  caRealiseMois: number;
  tauxPct: number | null;
};

/**
 * Suivi du CA réalisé vs objectif côté PROSPECTION : ce que les magasins issus
 * de la prospection facturent réellement (mois) face au potentiel signé, plus
 * le pipeline pondéré encore en jeu.
 */
export function ProspectionObjectifCard({ p }: { p: Prospection }) {
  const cibleMensuelle = p.potentielGagne > 0 ? p.potentielGagne / 12 : null;
  const taux = p.tauxPct;
  return (
    <section className="rounded-2xl bg-white shadow-card">
      <h2 className="flex items-center gap-2 border-b border-neutral-100 px-5 py-3.5 text-sm font-semibold dark:border-navy-700">
        <Sprout size={16} className="text-brand dark:text-accent" />
        Prospection — CA réalisé vs objectif
        <Link href="/pilotage/prospects" className="ml-auto text-xs font-medium text-brand hover:underline dark:text-accent">
          Ouvrir la prospection
        </Link>
      </h2>
      <div className="flex flex-col gap-4 px-5 py-4">
        {/* CA facturé par les magasins gagnés vs 1/12e du potentiel signé */}
        <div>
          <div className="mb-1.5 flex items-baseline justify-between">
            <span className="text-sm font-medium">Magasins issus de la prospection · ce mois</span>
            <span className="text-sm tabular-nums">
              <span className="font-bold">{EUR.format(p.caRealiseMois)}</span>
              {cibleMensuelle != null ? (
                <span className="text-neutral-400"> / {EUR.format(cibleMensuelle)}</span>
              ) : null}
              {taux != null ? (
                <span className={`ml-2 font-bold ${taux >= 100 ? 'text-emerald-500' : taux >= 70 ? 'text-amber-500' : 'text-red-400'}`}>
                  {taux} %
                </span>
              ) : null}
            </span>
          </div>
          <div className="relative h-2.5 w-full overflow-hidden rounded-full bg-neutral-100 dark:bg-navy-800">
            <div
              className={`h-full rounded-full transition-all ${taux != null && taux >= 100 ? 'bg-emerald-500' : taux != null && taux >= 70 ? 'bg-amber-400' : 'bg-red-400'}`}
              style={{ width: `${Math.min(taux ?? 0, 130) / 1.3}%` }}
            />
            <span className="absolute inset-y-0 border-l border-neutral-300 dark:border-navy-600" style={{ left: `${100 / 1.3}%` }} />
          </div>
          <p className="mt-1 text-xs text-neutral-400">
            Objectif mensuel = potentiel des {p.gagnes} prospect{p.gagnes > 1 ? 's' : ''} gagné{p.gagnes > 1 ? 's' : ''} ({EUR.format(p.potentielGagne)}/an) ÷ 12.
          </p>
        </div>

        {/* Pipeline encore en jeu */}
        <div className="flex items-center gap-2.5 rounded-xl border border-neutral-100 bg-neutral-50 px-3 py-2.5 dark:border-navy-700 dark:bg-navy-800/40">
          <TrendingUp size={16} className="shrink-0 text-[#7D8CCE]" />
          <p className="text-sm">
            <span className="font-bold tabular-nums">{EUR.format(p.pipelinePondere)}</span>
            <span className="text-neutral-500"> de pipeline pondéré sur </span>
            <span className="font-semibold">{p.ouverts}</span>
            <span className="text-neutral-500"> prospect{p.ouverts > 1 ? 's' : ''} en cours.</span>
          </p>
        </div>
      </div>
    </section>
  );
}
