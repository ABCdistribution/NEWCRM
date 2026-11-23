import { getFrequencesPem } from '@/lib/pem-api';
import { PemFrequencesEditeur } from './pem-frequences-editeur';

/** Rubrique de l'onglet Visites : fréquence des visites PEM selon la classe (A à G) du magasin. */
export async function AdminPemFrequences() {
  const frequences = await getFrequencesPem();

  return frequences ? (
    <PemFrequencesEditeur frequences={frequences} />
  ) : (
    <p className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
      Données indisponibles — l&apos;API est-elle démarrée ?
    </p>
  );
}
