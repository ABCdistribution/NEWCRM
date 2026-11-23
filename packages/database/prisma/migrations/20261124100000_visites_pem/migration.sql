-- Visites PEM : suivi PEM par magasin, fréquence par classe, propositions de visite, relevé des articles PEM.
-- Additive : colonnes avec valeur par défaut (clients.suiviPem, visites.typeVisite), nouvelles tables et nouveaux index ;
-- aucune donnée existante modifiée.
-- Retour arrière : DROP TABLE "propositions_pem", "visite_pem_articles", "frequences_pem_classes";
--   ALTER TABLE "visites" DROP COLUMN "typeVisite"; ALTER TABLE "clients" DROP COLUMN "suiviPem";
--   DROP TYPE "StatutPropositionPem"; DROP TYPE "TypeVisite";
-- CreateEnum
CREATE TYPE "TypeVisite" AS ENUM ('COMMERCIALE', 'PEM');

-- CreateEnum
CREATE TYPE "StatutPropositionPem" AS ENUM ('PROPOSEE', 'ACCEPTEE', 'REALISEE', 'ANNULEE');

-- AlterTable
ALTER TABLE "clients" ADD COLUMN     "suiviPem" BOOLEAN NOT NULL DEFAULT false;

-- AlterTable
ALTER TABLE "visites" ADD COLUMN     "typeVisite" "TypeVisite" NOT NULL DEFAULT 'COMMERCIALE';

-- CreateTable
CREATE TABLE "visite_pem_articles" (
    "id" UUID NOT NULL,
    "visiteId" UUID NOT NULL,
    "articleId" UUID NOT NULL,
    "present" BOOLEAN NOT NULL,
    "misEnAvant" BOOLEAN NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "visite_pem_articles_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "frequences_pem_classes" (
    "id" UUID NOT NULL,
    "niveauClass" "NiveauClass" NOT NULL,
    "semaines" INTEGER NOT NULL DEFAULT 4,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "frequences_pem_classes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "propositions_pem" (
    "id" UUID NOT NULL,
    "clientId" UUID NOT NULL,
    "promoteurId" UUID NOT NULL,
    "dateProposee" DATE NOT NULL,
    "statut" "StatutPropositionPem" NOT NULL DEFAULT 'PROPOSEE',
    "nbReports" INTEGER NOT NULL DEFAULT 0,
    "obligatoire" BOOLEAN NOT NULL DEFAULT false,
    "motifDernierReport" TEXT,
    "planningId" UUID,
    "visiteId" UUID,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "propositions_pem_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "visite_pem_articles_visiteId_idx" ON "visite_pem_articles"("visiteId");

-- CreateIndex
CREATE INDEX "visite_pem_articles_articleId_idx" ON "visite_pem_articles"("articleId");

-- CreateIndex
CREATE UNIQUE INDEX "visite_pem_articles_visiteId_articleId_key" ON "visite_pem_articles"("visiteId", "articleId");

-- CreateIndex
CREATE UNIQUE INDEX "frequences_pem_classes_niveauClass_key" ON "frequences_pem_classes"("niveauClass");

-- CreateIndex
CREATE UNIQUE INDEX "propositions_pem_visiteId_key" ON "propositions_pem"("visiteId");

-- CreateIndex
CREATE INDEX "propositions_pem_clientId_idx" ON "propositions_pem"("clientId");

-- CreateIndex
CREATE INDEX "propositions_pem_promoteurId_statut_idx" ON "propositions_pem"("promoteurId", "statut");

-- CreateIndex
CREATE INDEX "propositions_pem_planningId_idx" ON "propositions_pem"("planningId");

-- CreateIndex
CREATE INDEX "propositions_pem_updatedAt_idx" ON "propositions_pem"("updatedAt");

-- CreateIndex
CREATE INDEX "clients_suiviPem_idx" ON "clients"("suiviPem");

-- CreateIndex
CREATE INDEX "visites_clientId_typeVisite_idx" ON "visites"("clientId", "typeVisite");

-- AddForeignKey
ALTER TABLE "visite_pem_articles" ADD CONSTRAINT "visite_pem_articles_visiteId_fkey" FOREIGN KEY ("visiteId") REFERENCES "visites"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "visite_pem_articles" ADD CONSTRAINT "visite_pem_articles_articleId_fkey" FOREIGN KEY ("articleId") REFERENCES "articles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "propositions_pem" ADD CONSTRAINT "propositions_pem_clientId_fkey" FOREIGN KEY ("clientId") REFERENCES "clients"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "propositions_pem" ADD CONSTRAINT "propositions_pem_promoteurId_fkey" FOREIGN KEY ("promoteurId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "propositions_pem" ADD CONSTRAINT "propositions_pem_planningId_fkey" FOREIGN KEY ("planningId") REFERENCES "plannings"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "propositions_pem" ADD CONSTRAINT "propositions_pem_visiteId_fkey" FOREIGN KEY ("visiteId") REFERENCES "visites"("id") ON DELETE SET NULL ON UPDATE CASCADE;


-- Fréquence en semaines : au moins 1.
ALTER TABLE "frequences_pem_classes" ADD CONSTRAINT "frequences_pem_classes_semaines_check" CHECK ("semaines" >= 1);

-- Au plus UNE proposition ouverte (PROPOSEE / ACCEPTEE) par magasin (index partiel : non exprimable dans schema.prisma).
CREATE UNIQUE INDEX "propositions_pem_client_ouverte_key" ON "propositions_pem"("clientId") WHERE "statut" IN ('PROPOSEE', 'ACCEPTEE');

-- Les 7 classes A à G à 4 semaines (valeur par défaut, modifiable par la direction).
INSERT INTO "frequences_pem_classes" ("id", "niveauClass", "semaines", "updatedAt")
SELECT gen_random_uuid(), c::"NiveauClass", 4, CURRENT_TIMESTAMP
FROM unnest(ARRAY['A', 'B', 'C', 'D', 'E', 'F', 'G']) AS c
ON CONFLICT ("niveauClass") DO NOTHING;
