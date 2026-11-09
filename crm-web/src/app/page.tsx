// TODO(étape suivante) : page TEMPORAIRE de vérification des deux thèmes. À supprimer
// quand les groupes de routes (promoteurs) / (direction) et l'accueil réel existent.
import { ShieldAlert } from 'lucide-react';

const NIVEAUX = ['bg-navy-950', 'bg-navy-900', 'bg-navy-800', 'bg-navy-700', 'bg-navy-600'];

function Bloc({ espace, titre }: { espace: 'promoteurs' | 'direction'; titre: string }) {
  return (
    <section data-espace={espace} className="flex-1 space-y-4 p-6">
      <h2 className="text-xl font-semibold">{titre}</h2>
      <div className="flex flex-wrap items-center gap-3">
        <button className="rounded-lg bg-brand px-4 py-2 text-white focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent">
          Bouton brand
        </button>
        <span className="rounded-full bg-accent px-3 py-1 text-sm text-white">Badge accent</span>
        <span className="rounded-full bg-brand-light px-3 py-1 text-sm text-navy-950">Brand light</span>
        <span className="text-brand">Texte brand</span>
      </div>
      <div className="shadow-card rounded-xl bg-white p-4">
        <p className="mb-2 text-sm">Carte claire</p>
        <table className="w-full text-sm">
          <thead>
            <tr>
              <th className="text-left">Colonne</th>
              <th className="text-left">Valeur</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>Ligne</td>
              <td>42</td>
            </tr>
          </tbody>
        </table>
      </div>
      <div className="dark shadow-card rounded-xl bg-navy-950 p-4">
        <p className="flex items-center gap-2 text-sm">
          <ShieldAlert size={16} /> Carte / menu sombre
        </p>
        <p className="text-neutral-400">Texte neutre sur surface sombre</p>
        <div className="mt-2 flex gap-2">
          {NIVEAUX.map((n) => (
            <span key={n} className={`size-8 rounded ${n}`} title={n} />
          ))}
        </div>
      </div>
    </section>
  );
}

export default function PageTest() {
  return (
    <main className="flex min-h-screen flex-col md:flex-row">
      <Bloc espace="promoteurs" titre="Espace Promoteurs (bleu)" />
      <Bloc espace="direction" titre="Espace Direction (violet)" />
    </main>
  );
}
