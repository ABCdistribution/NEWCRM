import { Package, Truck, PackageCheck, PackageMinus } from 'lucide-react';
import type { StatutLivraison } from '@/lib/api';

/** Apparence de chaque statut de livraison (libellé court + couleurs + icône). */
export const LIVRAISON: Record<
  StatutLivraison,
  { label: string; classes: string; icon: typeof Package }
> = {
  EN_PREPARATION: {
    label: 'En préparation',
    classes: 'bg-neutral-500/10 text-neutral-500 dark:text-neutral-300',
    icon: Package,
  },
  EXPEDIEE: { label: 'Expédiée', classes: 'bg-blue-500/10 text-blue-600 dark:text-blue-400', icon: Truck },
  LIVREE_PARTIELLE: {
    label: 'Livrée partielle',
    classes: 'bg-amber-500/10 text-amber-600 dark:text-amber-400',
    icon: PackageMinus,
  },
  LIVREE: { label: 'Livrée', classes: 'bg-emerald-500/10 text-emerald-600 dark:text-emerald-400', icon: PackageCheck },
};

/** Pastille de suivi de livraison. Rien si la commande est annulée (sans objet). */
export function LivraisonBadge({ statut, annulee }: { statut: StatutLivraison; annulee?: boolean }) {
  if (annulee) return <span className="text-neutral-300">—</span>;
  const s = LIVRAISON[statut];
  const Icon = s.icon;
  return (
    <span className={`inline-flex items-center gap-1 whitespace-nowrap rounded-full px-2 py-0.5 text-xs font-medium ${s.classes}`}>
      <Icon size={12} />
      {s.label}
    </span>
  );
}
