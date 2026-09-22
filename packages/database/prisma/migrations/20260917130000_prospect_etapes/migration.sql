-- Historique des changements d'étape du pipeline prospect (timeline de la fiche).
CREATE TABLE "prospect_etapes" (
    "id" UUID NOT NULL,
    "prospectId" UUID NOT NULL,
    "auteurId" UUID,
    "de" "PipelineEtape",
    "vers" "PipelineEtape" NOT NULL,
    "commentaire" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "prospect_etapes_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "prospect_etapes_prospectId_idx" ON "prospect_etapes"("prospectId");
ALTER TABLE "prospect_etapes" ADD CONSTRAINT "prospect_etapes_prospectId_fkey" FOREIGN KEY ("prospectId") REFERENCES "prospects"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "prospect_etapes" ADD CONSTRAINT "prospect_etapes_auteurId_fkey" FOREIGN KEY ("auteurId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
