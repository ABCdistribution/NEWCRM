import { redirect } from 'next/navigation';
import { headers } from 'next/headers';

/**
 * Selios n'a plus de page de connexion propre : la connexion se fait sur le login
 * UNIQUE et neutre d'Helios, et le cookie de session est partagé entre les deux univers.
 * Cette route ne sert plus que de garde : un visiteur non connecté est déjà renvoyé
 * vers Helios par le middleware ; un visiteur connecté qui atterrit ici repart à l'accueil.
 */
export default async function LoginPage() {
  const host = (await headers()).get('host')?.split(':')[0] ?? 'localhost';
  const token = (await headers()).get('cookie')?.includes('crm_session=');
  if (token) redirect('/');
  redirect(`http://${host}:${process.env.HELIOS_PORT ?? '3001'}/login`);
}
