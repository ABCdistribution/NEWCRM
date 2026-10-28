import { redirect } from 'next/navigation';

/** L'ancienne page Utilisateurs est devenue un onglet de l'administration. */
export default function UsersRedirect() {
  redirect('/pilotage/admin?onglet=utilisateurs');
}
