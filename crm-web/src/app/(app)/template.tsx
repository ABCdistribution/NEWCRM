/** Se remonte à chaque navigation : fondu léger à l'arrivée sur une page (cf. .page-in dans globals.css). */
export default function Template({ children }: { children: React.ReactNode }) {
  return <div className="page-in">{children}</div>;
}
