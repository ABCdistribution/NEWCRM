-- Étape ADM (administrative) : pas de cible magasin/prospect.
ALTER TABLE "tournee_etapes" ADD COLUMN "adm" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "tournee_etapes" DROP CONSTRAINT "tournee_etapes_cible_check";
ALTER TABLE "tournee_etapes" ADD CONSTRAINT "tournee_etapes_cible_check"
  CHECK (
    ("adm" AND "clientId" IS NULL AND "prospectId" IS NULL)
    OR (NOT "adm" AND (("clientId" IS NOT NULL AND "prospectId" IS NULL) OR ("clientId" IS NULL AND "prospectId" IS NOT NULL)))
  );
