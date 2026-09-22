import { redirect } from 'next/navigation';

/** Racine : renvoie vers l'univers de pilotage (le layout gère le rôle). */
export default function RootPage() {
  redirect('/pilotage');
}
