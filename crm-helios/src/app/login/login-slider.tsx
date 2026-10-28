'use client';

import { useEffect, useState } from 'react';

/** Les univers de la gamme, présentés en boucle à côté du formulaire de connexion. */
const SLIDES = [
  {
    src: '/logo-abc-pilot.png',
    nom: 'ABC Pilot',
    glow: '124,102,255',
    titre: 'ABC Pilot, force commerciale',
    texte: "Pilotez l'activité commerciale et encadrez vos équipes terrain : clients, tournées, objectifs et commandes.",
  },
  {
    src: '/logo-thelios.png',
    nom: 'Thelios',
    glow: '251,191,36',
    titre: 'Thelios',
    texte: '',
  },
  {
    src: '/logo-ascendo.png',
    nom: 'Ascendo',
    glow: '16,185,129',
    titre: 'AscendoPilot, votre outil statistique',
    texte: "Suivez et analysez l'activité de vos magasins grâce à des statistiques claires et à jour.",
  },
  {
    src: '/logo-goback.png',
    nom: 'GoBack',
    glow: '234,138,92',
    titre: 'GoBack, la gestion des retours',
    texte: 'Déclarez et suivez les retours produits simplement, de la demande jusqu’à leur traitement.',
  },
] as const;

const DELAI_MS = 4500;

export function LoginSlider() {
  const [actif, setActif] = useState(0);
  const [pause, setPause] = useState(false);

  // Défilement automatique ; suspendu au survol et quand l'onglet est masqué.
  useEffect(() => {
    if (pause) return;
    const id = setInterval(() => {
      if (!document.hidden) setActif((i) => (i + 1) % SLIDES.length);
    }, DELAI_MS);
    return () => clearInterval(id);
  }, [pause]);

  return (
    <div
      className="relative flex h-full w-full flex-col items-center justify-center overflow-hidden"
      style={{ background: 'radial-gradient(90% 90% at 50% 40%, #16204a 0%, #0a1130 60%, #060a1f 100%)' }}
      onMouseEnter={() => setPause(true)}
      onMouseLeave={() => setPause(false)}
      role="group"
      aria-roledescription="carrousel"
      aria-label="Les univers de la gamme"
    >
      <style>{`
        @keyframes login-float { 0%, 100% { transform: translateY(0) } 50% { transform: translateY(-12px) } }
        @media (prefers-reduced-motion: reduce) { .login-float { animation: none !important } }
      `}</style>

      {/* Halo de couleur propre à chaque univers, en fondu enchaîné. */}
      {SLIDES.map((s, i) => (
        <div
          key={s.nom}
          aria-hidden
          className="pointer-events-none absolute inset-0 transition-opacity duration-1000 ease-in-out"
          style={{
            opacity: i === actif ? 1 : 0,
            background: `radial-gradient(55% 45% at 50% 42%, rgba(${s.glow},.32) 0%, transparent 70%)`,
          }}
        />
      ))}

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
                style={{
                  boxShadow: `0 30px 80px -20px rgba(${s.glow},.45)`,
                  animation: 'login-float 7s ease-in-out infinite',
                }}
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

      {/* Indicateurs. */}
      <div className="relative mt-2 flex items-center gap-2.5">
        {SLIDES.map((s, i) => (
          <button
            key={s.nom}
            type="button"
            onClick={() => setActif(i)}
            aria-label={`Afficher ${s.nom}`}
            aria-current={i === actif}
            className={`h-2 rounded-full transition-all duration-500 ${
              i === actif ? 'w-8 bg-white' : 'w-2 bg-white/35 hover:bg-white/60'
            }`}
          />
        ))}
      </div>
    </div>
  );
}
