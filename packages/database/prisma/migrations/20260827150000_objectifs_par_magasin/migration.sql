-- Refonte des objectifs : par MAGASIN et par ANNÉE (saisis par la direction),
-- au lieu de par représentant et par mois. Les anciennes cibles de test sont abandonnées.
DROP TABLE "objectifs";

CREATE TABLE "objectifs" (
  "id" UUID NOT NULL,
  "clientId" UUID NOT NULL,
  "annee" INTEGER NOT NULL,
  "cibleCa" DECIMAL(14,2) NOT NULL,
  "creeParId" UUID,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "objectifs_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "objectifs_clientId_annee_key" ON "objectifs"("clientId", "annee");
CREATE INDEX "objectifs_annee_idx" ON "objectifs"("annee");

ALTER TABLE "objectifs" ADD CONSTRAINT "objectifs_clientId_fkey"
  FOREIGN KEY ("clientId") REFERENCES "clients"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "objectifs" ADD CONSTRAINT "objectifs_creeParId_fkey"
  FOREIGN KEY ("creeParId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
