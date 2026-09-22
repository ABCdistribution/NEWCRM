-- Modernisation des récurrences de planning (table vide : refonte sans risque)
-- semaineDebut/annee (héritage legacy) remplacés par une ancre de date.
ALTER TABLE "plannifications" DROP COLUMN "semaineDebut";
ALTER TABLE "plannifications" DROP COLUMN "annee";
ALTER TABLE "plannifications" ALTER COLUMN "jours" SET NOT NULL;
ALTER TABLE "plannifications" ALTER COLUMN "recurrence" SET NOT NULL;
ALTER TABLE "plannifications" ALTER COLUMN "recurrence" SET DEFAULT 1;
ALTER TABLE "plannifications" ADD COLUMN "dateDebut" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE "plannifications" ADD COLUMN "dateFin" TIMESTAMP(3);
