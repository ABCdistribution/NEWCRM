import { ShieldAlert } from 'lucide-react';
import { getMe, listQuestionnaire } from '@/lib/api';
import { QuestionnaireEditor } from '@/components/questionnaire-editor';

export const metadata = { title: 'Questionnaire visite — Helios' };

export default async function QuestionnairePage() {
  const me = await getMe();
  if (!me || !['ADMIN', 'DIRECTION'].includes(me.role)) {
    return (
      <div className="rounded-xl border border-red-200 bg-red-50 p-6 text-red-700">
        <h1 className="flex items-center gap-2 text-lg font-semibold">
          <ShieldAlert size={20} />
          Accès refusé
        </h1>
        <p className="mt-1 text-sm">L&apos;édition du questionnaire est réservée à la direction.</p>
      </div>
    );
  }

  const questions = await listQuestionnaire();

  return (
    <div className="flex flex-col gap-4">
      <div>
        <h1 className="text-2xl font-bold">Questionnaire de fin de visite</h1>
        <p className="text-sm text-neutral-500">
          La structure du compte-rendu que le promoteur remplit sur l&apos;app mobile à la fin de
          chaque visite : cases à cocher, notes, champs libres. Modifiable à tout moment — les
          visites déjà saisies gardent leurs réponses.
        </p>
      </div>

      {!questions ? (
        <p className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
          Questionnaire indisponible — l&apos;API est-elle démarrée ?
        </p>
      ) : (
        <QuestionnaireEditor questions={questions} />
      )}
    </div>
  );
}
