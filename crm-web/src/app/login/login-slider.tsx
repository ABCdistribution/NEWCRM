'use client';

import { useEffect, useState } from 'react';

/**
 * Univers présentés à côté du formulaire de connexion. AscendoPilot et GoBack ont été retirés à la demande de
 * l'utilisateur : ne plus les annoncer ici. Le carrousel défile (et affiche ses indicateurs) dès qu'il y a
 * plusieurs diapositives ; avec une seule, c'est une simple présentation fixe.
 */
const SLIDES = [
  {
    src: '/logo-thelios.png',
    nom: 'Thelios',
    titre: 'Thelios',
    texte: '',
  },
] as const;

const DELAI_MS = 4500;

export function LoginSlider() {
  const [actif, setActif] = useState(0);
  const [pause, setPause] = useState(false);
  const plusieurs = SLIDES.length > 1;

  // Défilement automatique ; suspendu au survol et quand l'onglet est masqué.
  useEffect(() => {
    if (pause || !plusieurs) return;
    const id = setInterval(() => {
      if (!document.hidden) setActif((i) => (i + 1) % SLIDES.length);
    }, DELAI_MS);
    return () => clearInterval(id);
  }, [pause, plusieurs]);

  return (
    <div
      // Fond en aplat (jeton navy du thème posé sur <main>) : pas de dégradé de couleur sur le web.
      className="relative flex h-full w-full flex-col items-center justify-center overflow-hidden bg-navy-950"
      onMouseEnter={() => setPause(true)}
      onMouseLeave={() => setPause(false)}
      role="group"
      aria-roledescription={plusieurs ? 'carrousel' : undefined}
      aria-label="Les univers de la gamme"
    >
      <style>{`
        @keyframes login-float { 0%, 100% { transform: translateY(0) } 50% { transform: translateY(-12px) } }
        @media (prefers-reduced-motion: reduce) { .login-float { animation: none !important } }
      `}</style>

      {/* Diapositives : fondu + léger glissement latéral, en boucle continue. */}
      <div className="relative h-[min(40vh,22rem)] w-full max-w-[22rem]">
        {SLIDES.map((s, i) => {
          const decalage = (i - actif + SLIDES.length) % SLIDES.length;
          const position =
            decalage === 0
              ? 'translate-x-0 scale-100 opacity-100'
              : decalage === SLIDES.length - 1
                ? '-translate-x-24 scale-90 opacity-0'
                : 'translate-x-24 scale-90 opacity-0';
          return (
            <div
              key={s.nom}
              aria-hidden={i !== actif}
              className={`absolute inset-0 flex items-center justify-center transition-all duration-[900ms] ease-[cubic-bezier(.45,0,.2,1)] motion-reduce:transition-none ${position}`}
            >
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={s.src}
                alt={s.nom}
                draggable={false}
                className="login-float aspect-square h-full max-h-full w-auto rounded-[2rem] object-cover shadow-2xl ring-1 ring-white/10"
                style={{ animation: 'login-float 7s ease-in-out infinite' }}
              />
            </div>
          );
        })}
      </div>

      {/* Légende : titre + phrase, en fondu avec le logo. */}
      <div className="relative mt-8 h-32 w-full max-w-md px-6 text-center">
        {SLIDES.map((s, i) => (
          <div
            key={s.nom}
            aria-hidden={i !== actif}
            className={`absolute inset-x-6 top-0 transition-all duration-[900ms] ease-[cubic-bezier(.45,0,.2,1)] motion-reduce:transition-none ${
              i === actif ? 'translate-y-0 opacity-100' : 'translate-y-3 opacity-0'
            }`}
          >
            <p className="text-xl font-bold text-white">{s.titre}</p>
            {s.texte ? <p className="mt-2 text-sm leading-relaxed text-white/70">{s.texte}</p> : null}
          </div>
        ))}
      </div>

      {/* Indicateurs (seulement s'il y a plusieurs diapositives). */}
      {plusieurs ? (
        <div className="relative mt-2 flex items-center gap-2.5">
          {SLIDES.map((s, i) => (
            <button
              key={s.nom}
              type="button"
              onClick={() => setActif(i)}
              aria-label={`Afficher ${s.nom}`}
              aria-current={i === actif}
              className={`h-2 rounded-full transition-all duration-500 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-white ${
                i === actif ? 'w-8 bg-white' : 'w-2 bg-white/35 hover:bg-white/60'
              }`}
            />
          ))}
        </div>
      ) : null}
    </div>
  );
}
