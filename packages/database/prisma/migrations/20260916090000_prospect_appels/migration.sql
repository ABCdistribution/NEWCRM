-- Journal des appels téléphoniques passés aux prospects (saisis sur l'app mobile,
-- affichés dans la timeline de la fiche prospect).
CREATE TYPE "ResultatAppel" AS ENUM ('REPONDU', 'SANS_REPONSE', 'MESSAGERIE', 'RAPPEL_PREVU');

CREATE TABLE "prospect_appels" (
    "id" UUID NOT NULL,
    "prospectId" UUID NOT NULL,
    "auteurId" UUID,
    "dateAppel" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "dureeSec" INTEGER,
    "resultat" "ResultatAppel" NOT NULL DEFAULT 'REPONDU',
    "commentaire" TEXT,
    "idApk" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "prospect_appels_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "prospect_appels_idApk_key" ON "prospect_appels"("idApk");
CREATE INDEX "prospect_appels_prospectId_idx" ON "prospect_appels"("prospectId");
CREATE INDEX "prospect_appels_auteurId_idx" ON "prospect_appels"("auteurId");

ALTER TABLE "prospect_appels" ADD CONSTRAINT "prospect_appels_prospectId_fkey" FOREIGN KEY ("prospectId") REFERENCES "prospects"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "prospect_appels" ADD CONSTRAINT "prospect_appels_auteurId_fkey" FOREIGN KEY ("auteurId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
