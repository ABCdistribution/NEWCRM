'use client';

import { useEffect, useState } from 'react';
import { Moon, Sun } from 'lucide-react';

/** Bascule clair / sombre — pose `.dark` sur <html> et mémorise le choix. */
export function ThemeToggle() {
  const [dark, setDark] = useState<boolean | null>(null);

  useEffect(() => {
    setDark(document.documentElement.classList.contains('dark'));
  }, []);

  function toggle() {
    const next = !document.documentElement.classList.contains('dark');
    document.documentElement.classList.toggle('dark', next);
    try {
      localStorage.setItem('theme', next ? 'dark' : 'light');
    } catch {
      // stockage indisponible (navigation privée) — le choix ne persiste pas
    }
    setDark(next);
  }

  return (
    <button
      type="button"
      onClick={toggle}
      className="rounded-lg p-2 text-neutral-400 transition hover:bg-accent/20 hover:text-accent"
      aria-label={dark ? 'Passer en clair' : 'Passer en sombre'}
      title={dark ? 'Mode clair' : 'Mode sombre'}
    >
      {dark ? <Sun size={16} /> : <Moon size={16} />}
    </button>
  );
}
