-- Questionnaire de fin de visite administrable (helios) + réponses (app mobile).
CREATE TYPE "TypeQuestion" AS ENUM ('CASE_A_COCHER', 'TEXTE', 'NOMBRE', 'NOTE_1_5');

CREATE TABLE "questions_visite" (
  "id" UUID NOT NULL,
  "libelle" TEXT NOT NULL,
  "type" "TypeQuestion" NOT NULL DEFAULT 'CASE_A_COCHER',
  "ordre" INTEGER NOT NULL,
  "obligatoire" BOOLEAN NOT NULL DEFAULT false,
  "actif" BOOLEAN NOT NULL DEFAULT true,
  "creeParId" UUID,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  "deletedAt" TIMESTAMP(3),
  CONSTRAINT "questions_visite_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "questions_visite_ordre_idx" ON "questions_visite"("ordre");
ALTER TABLE "questions_visite" ADD CONSTRAINT "questions_visite_creeParId_fkey"
  FOREIGN KEY ("creeParId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE TABLE "visite_reponses" (
  "id" UUID NOT NULL,
  "visiteId" UUID NOT NULL,
  "questionId" UUID NOT NULL,
  "valeur" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "visite_reponses_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "visite_reponses_visiteId_questionId_key" ON "visite_reponses"("visiteId", "questionId");
CREATE INDEX "visite_reponses_questionId_idx" ON "visite_reponses"("questionId");
ALTER TABLE "visite_reponses" ADD CONSTRAINT "visite_reponses_visiteId_fkey"
  FOREIGN KEY ("visiteId") REFERENCES "visites"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "visite_reponses" ADD CONSTRAINT "visite_reponses_questionId_fkey"
  FOREIGN KEY ("questionId") REFERENCES "questions_visite"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
