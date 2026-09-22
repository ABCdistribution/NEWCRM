'use client';

import { useState } from 'react';
import { Plus, X, Pencil, Trash2, Image as ImageIcon, User, CalendarDays, Check, Upload } from 'lucide-react';

type News = {
  id: string;
  titre: string;
  extrait: string;
  auteur: string;
  date: string;
  publiee: boolean;
  photo?: string;
};

const INIT: News[] = [
  { id: 'n1', titre: 'Nouveautés HQ Mai', auteur: 'Manon LESAFFRE', date: '26/05/2026', publiee: true, extrait: 'Bonjour à tous, je vous informe que les 3 nouveautés HQ suivantes sont disponibles : masques, cravates et coffrets.' },
  { id: 'n2', titre: "JLD MANUCURE - RUPTURE PAE JUSQU'À FIN MAI 2026", auteur: 'Marion CARON', date: '06/05/2026', publiee: true, extrait: 'Rupture sur les nouvelles références PAE JLD. Anciennes références à commander : 21244212…' },
  { id: 'n3', titre: 'CRAVATE BUCCODENTAIRE APOTEKE DISPONIBLE', auteur: 'Manon LESAFFRE', date: '11/03/2026', publiee: true, extrait: "Bonjour à tous, l'ensemble des références buccodentaire APOTEKE est de nouveau disponible (gratuité incluse)." },
  { id: 'n4', titre: 'LES MASQUES COREENS ET LA CRAVATE HQ SONT DE NOUVEAU EN STOCK !', auteur: 'Manon LESAFFRE', date: '10/03/2026', publiee: true, extrait: 'Bonjour à tous, le masque Collagène HQ Made in Corée est de nouveau en stock ainsi que la cravate.' },
  { id: 'n5', titre: 'LES MASQUES HQ MADE IN COREE SONT DISPONIBLES !', auteur: 'Manon LESAFFRE', date: '17/02/2026', publiee: true, extrait: 'Tous les masques HQ Made in Corée sont de nouveau en stock ! Ils peuvent être commandés via les codes…' },
  { id: 'n6', titre: 'URGENT : RUPTURE 7199 BROSSE STITCH', auteur: 'Cécile CALCUL', date: '05/12/2025', publiee: true, extrait: "La référence 7199 brosse Stitch est en rupture. Le switch est d'ores et déjà actif dans le CRM." },
  { id: 'n7', titre: 'Rappel – Prêts-à-vendre Mini Prix Franck Provost déjà disponibles !', auteur: 'Audrey BRUN', date: '23/09/2025', publiee: true, extrait: 'Bonjour à tous, nous vous rappelons que 2 prêts-à-vendre Franck Provost – Mini Prix sont déjà disponibles.' },
  { id: 'n8', titre: 'Disponibilité nouveautés Puériculture – Couverts silicone Tom & Jerry et Thermomètre bain Titi', auteur: 'Audrey BRUN', date: '23/09/2025', publiee: false, extrait: "Bonjour à tous, j'ai le plaisir de vous annoncer que de nouvelles références viennent enrichir notre gamme." },
];

function todayFr(): string {
  const d = new Date();
  return `${String(d.getDate()).padStart(2, '0')}/${String(d.getMonth() + 1).padStart(2, '0')}/${d.getFullYear()}`;
}

function Thumb({ src }: { src?: string }) {
  if (src) {
    // eslint-disable-next-line @next/next/no-img-element
    return <img src={src} alt="" className="h-11 w-14 shrink-0 rounded-lg border border-neutral-100 object-cover dark:border-navy-700" />;
  }
  return (
    <span className="flex h-11 w-14 shrink-0 items-center justify-center rounded-lg bg-gradient-to-br from-brand/20 to-brand/5 text-brand dark:text-accent">
      <ImageIcon size={18} />
    </span>
  );
}

export function NewsBoard({ canManage, me }: { canManage: boolean; me: string }) {
  const [news, setNews] = useState<News[]>(INIT);
  const [editing, setEditing] = useState<News | 'new' | null>(null);

  const save = (n: News) => {
    setNews((list) => (list.some((x) => x.id === n.id) ? list.map((x) => (x.id === n.id ? n : x)) : [n, ...list]));
    setEditing(null);
  };
  const remove = (id: string) => {
    setNews((list) => list.filter((x) => x.id !== id));
    setEditing(null);
  };

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold">Les News ABC</h1>
          <p className="text-sm text-neutral-500">Actualités et communications diffusées à la force de vente.</p>
        </div>
        {canManage ? (
          <button
            type="button"
            onClick={() => setEditing('new')}
            className="inline-flex items-center gap-1.5 rounded-xl bg-brand px-3 py-2 text-sm font-medium text-white transition hover:bg-brand/90 dark:bg-accent dark:text-brand dark:hover:bg-accent/80"
          >
            <Plus size={15} /> Créer une news
          </button>
        ) : null}
      </div>

      <div className="overflow-x-auto rounded-xl bg-white shadow-card">
        <table className="w-full text-sm">
          <thead className="bg-neutral-50 text-left text-neutral-500 dark:bg-navy-950/50">
            <tr>
              <th className="px-4 py-2.5 font-medium">Photo</th>
              <th className="px-4 py-2.5 font-medium">Titre</th>
              <th className="px-4 py-2.5 font-medium">Créé par</th>
              <th className="px-4 py-2.5 font-medium">Date de création</th>
              <th className="px-4 py-2.5 text-center font-medium">Publiée&nbsp;?</th>
              {canManage ? <th className="px-4 py-2.5 text-right font-medium">Actions</th> : null}
            </tr>
          </thead>
          <tbody className="divide-y divide-neutral-100 dark:divide-navy-700">
            {news.map((n) => (
              <tr key={n.id} className="hover:bg-neutral-50 dark:hover:bg-navy-800/50">
                <td className="px-4 py-3"><Thumb src={n.photo} /></td>
                <td className="px-4 py-3">
                  <p className="font-semibold">{n.titre}</p>
                  <p className="mt-0.5 line-clamp-1 max-w-xl text-xs italic text-neutral-400">{n.extrait}</p>
                </td>
                <td className="px-4 py-3">
                  <span className="inline-flex items-center gap-1.5 text-neutral-600 dark:text-neutral-300"><User size={13} className="text-neutral-400" /> {n.auteur}</span>
                </td>
                <td className="px-4 py-3">
                  <span className="inline-flex items-center gap-1.5 text-neutral-500"><CalendarDays size={13} className="text-neutral-400" /> {n.date}</span>
                </td>
                <td className="px-4 py-3 text-center">
                  {n.publiee ? (
                    <Check size={16} className="mx-auto text-emerald-500" />
                  ) : (
                    <span className="mx-auto inline-block rounded-full bg-neutral-400/15 px-2 py-0.5 text-xs text-neutral-500">Brouillon</span>
                  )}
                </td>
                {canManage ? (
                  <td className="px-4 py-3 text-right">
                    <button type="button" onClick={() => setEditing(n)} className="inline-flex items-center gap-1 rounded-lg border border-neutral-200 px-2 py-1.5 text-xs font-medium text-neutral-600 transition hover:border-brand hover:text-brand dark:border-navy-700 dark:text-neutral-300 dark:hover:border-accent dark:hover:text-accent" aria-label="Éditer">
                      <Pencil size={13} /> Éditer
                    </button>
                  </td>
                ) : null}
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {editing ? (
        <NewsModal
          news={editing === 'new' ? null : editing}
          auteur={me}
          onClose={() => setEditing(null)}
          onSave={save}
          onDelete={remove}
        />
      ) : null}
    </div>
  );
}

function NewsModal({
  news,
  auteur,
  onClose,
  onSave,
  onDelete,
}: {
  news: News | null;
  auteur: string;
  onClose: () => void;
  onSave: (n: News) => void;
  onDelete: (id: string) => void;
}) {
  const [titre, setTitre] = useState(news?.titre ?? '');
  const [extrait, setExtrait] = useState(news?.extrait ?? '');
  const [publiee, setPubliee] = useState(news?.publiee ?? false);
  const [photo, setPhoto] = useState<string | undefined>(news?.photo);

  const field = 'w-full rounded-lg border border-neutral-200 bg-white px-3 py-2 text-sm outline-none transition focus:border-brand dark:border-navy-700 dark:bg-navy-950';

  const onFile = (e: React.ChangeEvent<HTMLInputElement>) => {
    const f = e.target.files?.[0];
    if (!f) return;
    const reader = new FileReader();
    reader.onload = () => setPhoto(reader.result as string);
    reader.readAsDataURL(f);
  };

  const submit = () => {
    if (!titre.trim()) return;
    onSave({
      id: news?.id ?? `n${Date.now()}`,
      titre: titre.trim(),
      extrait: extrait.trim(),
      publiee,
      photo,
      auteur: news?.auteur ?? auteur,
      date: news?.date ?? todayFr(),
    });
  };

  return (
    <div className="fixed inset-0 z-50 flex items-start justify-center overflow-y-auto bg-black/40 p-4 pt-12" onClick={onClose}>
      <div className="w-full max-w-lg rounded-2xl bg-white p-5 shadow-xl dark:bg-navy-900" onClick={(e) => e.stopPropagation()}>
        <div className="mb-4 flex items-center justify-between">
          <h2 className="text-lg font-bold">{news ? 'Éditer la news' : 'Créer une news'}</h2>
          <button type="button" onClick={onClose} className="text-neutral-400 hover:text-neutral-600" aria-label="Fermer"><X size={18} /></button>
        </div>

        <div className="flex flex-col gap-3">
          <label className="flex flex-col gap-1">
            <span className="text-xs font-medium text-neutral-500">Titre</span>
            <input value={titre} onChange={(e) => setTitre(e.target.value)} placeholder="Titre de la news" className={field} />
          </label>
          <label className="flex flex-col gap-1">
            <span className="text-xs font-medium text-neutral-500">Contenu</span>
            <textarea value={extrait} onChange={(e) => setExtrait(e.target.value)} rows={5} placeholder="Contenu de la news…" className={field} />
          </label>

          <div className="flex flex-col gap-1">
            <span className="text-xs font-medium text-neutral-500">Photo</span>
            <div className="flex items-center gap-3">
              {photo ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={photo} alt="" className="h-16 w-20 rounded-lg border border-neutral-200 object-cover dark:border-navy-700" />
              ) : (
                <span className="flex h-16 w-20 items-center justify-center rounded-lg border border-dashed border-neutral-300 text-neutral-300 dark:border-navy-700">
                  <ImageIcon size={20} />
                </span>
              )}
              <label className="inline-flex cursor-pointer items-center gap-1.5 rounded-lg border border-neutral-200 px-3 py-2 text-sm font-medium text-neutral-600 transition hover:border-brand hover:text-brand dark:border-navy-700 dark:text-neutral-300">
                <Upload size={15} /> {photo ? 'Changer' : 'Choisir une image'}
                <input type="file" accept="image/*" onChange={onFile} className="hidden" />
              </label>
              {photo ? (
                <button type="button" onClick={() => setPhoto(undefined)} className="text-sm text-neutral-400 hover:text-red-500">Retirer</button>
              ) : null}
            </div>
          </div>

          <label className="inline-flex cursor-pointer items-center gap-2 text-sm">
            <input type="checkbox" checked={publiee} onChange={(e) => setPubliee(e.target.checked)} className="accent-brand" />
            Publiée (visible par la force de vente)
          </label>

          <div className="mt-2 flex items-center justify-between gap-2">
            {news ? (
              <button type="button" onClick={() => onDelete(news.id)} className="inline-flex items-center gap-1.5 rounded-lg border border-red-200 px-3 py-2 text-sm font-medium text-red-600 transition hover:bg-red-50 dark:border-red-900/50 dark:hover:bg-red-950/30">
                <Trash2 size={15} /> Supprimer
              </button>
            ) : <span />}
            <div className="flex gap-2">
              <button type="button" onClick={onClose} className="rounded-lg px-3 py-2 text-sm text-neutral-500 hover:text-neutral-700">Annuler</button>
              <button type="button" onClick={submit} className="inline-flex items-center gap-1.5 rounded-xl bg-brand px-4 py-2 text-sm font-medium text-white transition hover:bg-brand/90 dark:bg-accent dark:text-brand dark:hover:bg-accent/80">
                <Check size={15} /> {news ? 'Enregistrer' : 'Créer'}
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
