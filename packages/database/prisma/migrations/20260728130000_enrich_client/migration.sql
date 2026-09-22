-- Enrichissement du modèle Client (aligné sur l'ancien `ref_client`)

-- Enum note CRM (ex-niveau_class A→G)
CREATE TYPE "NiveauClass" AS ENUM ('A', 'B', 'C', 'D', 'E', 'F', 'G');

-- Renommages (sans perte de données)
ALTER TABLE "clients" RENAME COLUMN "adresse" TO "adresse1";
ALTER TABLE "clients" RENAME COLUMN "telephone" TO "tel1";

-- Nouvelles colonnes
ALTER TABLE "clients"
  ADD COLUMN "adresse2" TEXT,
  ADD COLUMN "adresse3" TEXT,
  ADD COLUMN "codePostal2" TEXT,
  ADD COLUMN "langue" TEXT,
  ADD COLUMN "devise" TEXT,
  ADD COLUMN "siret" TEXT,
  ADD COLUMN "eanClient" TEXT,
  ADD COLUMN "tel2" TEXT,
  ADD COLUMN "contact1" TEXT,
  ADD COLUMN "contact2" TEXT,
  ADD COLUMN "contact3" TEXT,
  ADD COLUMN "niveauClass" "NiveauClass",
  ADD COLUMN "statutCommande" TEXT,
  ADD COLUMN "statutLivre" TEXT,
  ADD COLUMN "statutFacture" TEXT,
  ADD COLUMN "creeParId" UUID;

-- Index + clé étrangère du créateur
CREATE INDEX "clients_creeParId_idx" ON "clients"("creeParId");
ALTER TABLE "clients" ADD CONSTRAINT "clients_creeParId_fkey" FOREIGN KEY ("creeParId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
