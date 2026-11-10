import { redirect } from 'next/navigation';

/** L'ancienne page Utilisateurs est devenue un onglet de l'administration (qui rappelle son contrôle ADMIN). */
export default function UsersRedirect() {
  redirect('/admin?onglet=utilisateurs');
}
