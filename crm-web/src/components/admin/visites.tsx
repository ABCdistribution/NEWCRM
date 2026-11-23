import { listQuestionnaire, listRaisonsAbsence } from '@/lib/visites-admin-api';
import { QuestionnaireEditeur, RaisonsEditeur } from './visites-editeurs';
import { AdminProduitsIndispensables } from './produits-indispensables';
import { AdminPemFrequences } from './pem-frequences';

const INDISPONIBLE = (
  <p className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800">
    Données indisponibles — l&apos;API est-elle démarrée ?
  </p>
);

/** Onglet Visites : questionnaire de fin de visite et raisons d'absence de commande. */
export async function AdminVisitesOnglet() {
  const [questions, raisons] = await Promise.all([listQuestionnaire(), listRaisonsAbsence()]);

  return (
    <div className="flex flex-col gap-8">
      <section aria-labelledby="titre-questionnaire" className="flex flex-col gap-3">
        <h2 id="titre-questionnaire" className="text-base font-semibold">
          Questionnaire de fin de visite
        </h2>
        {questions ? <QuestionnaireEditeur questions={questions} /> : INDISPONIBLE}
      </section>
      <section aria-labelledby="titre-raisons" className="flex flex-col gap-3">
        <h2 id="titre-raisons" className="text-base font-semibold">
          Raisons d&apos;absence de commande
        </h2>
        {raisons ? <RaisonsEditeur raisons={raisons} /> : INDISPONIBLE}
      </section>
      <section aria-labelledby="titre-indispensables" className="flex flex-col gap-3">
        <h2 id="titre-indispensables" className="text-base font-semibold">
          Produits indispensables par enseigne
        </h2>
        <AdminProduitsIndispensables />
      </section>
      <section aria-labelledby="titre-pem-frequences" className="flex flex-col gap-3">
        <h2 id="titre-pem-frequences" className="text-base font-semibold">
          Visites PEM — fréquence par classe
        </h2>
        <AdminPemFrequences />
      </section>
    </div>
  );
}
