import { redirect } from 'next/navigation';

/** Les paramètres sont devenus l'onglet Configuration de l'administration. */
export default function ParametresRedirect() {
  redirect('/pilotage/admin?onglet=configuration');
}
