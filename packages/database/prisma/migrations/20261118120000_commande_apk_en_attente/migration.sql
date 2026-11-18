-- Commandes mobiles en attente (brouillon modifiable, éventuellement envoyé par mail au client pour validation).
-- Additive : toutes les lignes existantes prennent le statut VALIDEE (comportement historique).
-- Retour arrière : DROP INDEX "commandes_apk_statut_idx" ;
-- ALTER TABLE "commandes_apk" DROP COLUMN "statut", DROP COLUMN "emailValidation", DROP COLUMN "emailEnvoyeLe", DROP COLUMN "valideeLe" ;
-- DROP TYPE "StatutCommandeApk".
CREATE TYPE "StatutCommandeApk" AS ENUM ('EN_ATTENTE', 'VALIDEE');

ALTER TABLE "commandes_apk" ADD COLUMN "statut" "StatutCommandeApk" NOT NULL DEFAULT 'VALIDEE';
ALTER TABLE "commandes_apk" ADD COLUMN "emailValidation" TEXT;
ALTER TABLE "commandes_apk" ADD COLUMN "emailEnvoyeLe" TIMESTAMP(3);
ALTER TABLE "commandes_apk" ADD COLUMN "valideeLe" TIMESTAMP(3);

CREATE INDEX "commandes_apk_statut_idx" ON "commandes_apk"("statut");
