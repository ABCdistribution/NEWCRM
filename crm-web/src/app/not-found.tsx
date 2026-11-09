import { PageIntrouvable } from '@/components/page-introuvable';

/** 404 de la racine (adresse qui ne correspond à aucune page) : pas de menu, l'espace n'est pas connu ici. */
export default function NonTrouvee() {
  return (
    <main className="flex min-h-screen items-center justify-center px-4 py-8">
      <PageIntrouvable />
    </main>
  );
}
