import { listCentrales, listProduitsIndispensables } from '@/lib/produits-indispensables-api';
import { ProduitsIndispensablesEditeur } from './produits-indispensables-editeur';

/** Rubrique de l'onglet Visites : produits indispensables à vérifier, par enseigne (centrale). */
export async function AdminProduitsIndispensables() {
  const [centrales, lignes] = await Promise.all([listCentrales(), listProduitsIndispensables()]);

  return centrales && lignes ? (
    <ProduitsIndispensablesEditeur centrales={centrales} lignes={lignes} />
  ) : (
    <p className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
      Données indisponibles — l&apos;API est-elle démarrée ?
    </p>
  );
}
