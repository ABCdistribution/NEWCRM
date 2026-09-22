-- Pipeline prospection : l'étape VISITE remplace QUALIFIE
-- (création de la fiche → prise de contact → proposition → visite → négociation → gagné / perdu).
-- Les prospects « qualifiés » existants redeviennent « contactés ».
CREATE TYPE "PipelineEtape_new" AS ENUM ('NOUVEAU', 'CONTACTE', 'PROPOSITION', 'VISITE', 'NEGOCIATION', 'GAGNE', 'PERDU');
ALTER TABLE "prospects" ALTER COLUMN "statut" DROP DEFAULT;
UPDATE "prospects" SET "statut" = 'CONTACTE' WHERE "statut" = 'QUALIFIE';
ALTER TABLE "prospects" ALTER COLUMN "statut" TYPE "PipelineEtape_new" USING ("statut"::text::"PipelineEtape_new");
ALTER TYPE "PipelineEtape" RENAME TO "PipelineEtape_old";
ALTER TYPE "PipelineEtape_new" RENAME TO "PipelineEtape";
DROP TYPE "PipelineEtape_old";
ALTER TABLE "prospects" ALTER COLUMN "statut" SET DEFAULT 'NOUVEAU';

-- Classe estimée du magasin, renseignée dès la création de la fiche prospect.
ALTER TABLE "prospects" ADD COLUMN "niveauClass" "NiveauClass";
