import { ShieldAlert } from 'lucide-react';
import { getMe, listPromos, listPem } from '@/lib/api';
import { PromosEditor } from '@/components/promos-editor';

export const metadata = { title: 'Promos / PEM — Helios' };

export default async function PromosPage() {
  const me = await getMe();
  if (!me || !['ADMIN', 'DIRECTION', 'MARKETING'].includes(me.role)) {
    return (
      <div className="rounded-xl border border-red-200 bg-red-50 p-6 text-red-700">
        <h1 className="flex items-center gap-2 text-lg font-semibold">
          <ShieldAlert size={20} />
          Accès refusé
        </h1>
        <p className="mt-1 text-sm">La gestion des promos est réservée à la direction et au marketing.</p>
      </div>
    );
  }

  const [promos, pem] = await Promise.all([listPromos(), listPem()]);

  return (
    <div className="flex flex-col gap-4">
      <div>
        <h1 className="text-2xl font-bold">Promos / PEM</h1>
        <p className="text-sm text-neutral-500">
          Offres promotionnelles et articles mis en avant à pousser en visite. Ils remontent
          automatiquement sur l&apos;app mobile (badges PROMO / mise en avant) à la prochaine
          synchronisation des commerciaux.
        </p>
      </div>

      {!promos || !pem ? (
        <p className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
          Données indisponibles — l&apos;API est-elle démarrée ?
        </p>
      ) : (
        <PromosEditor promos={promos} pem={pem} />
      )}
    </div>
  );
}
