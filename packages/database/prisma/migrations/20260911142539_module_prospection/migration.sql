-- CreateEnum
CREATE TYPE "PipelineEtape" AS ENUM ('NOUVEAU', 'CONTACTE', 'QUALIFIE', 'PROPOSITION', 'NEGOCIATION', 'GAGNE', 'PERDU');

-- CreateEnum
CREATE TYPE "SourceProspect" AS ENUM ('SALON', 'RECOMMANDATION', 'TERRAIN', 'WEB');

-- CreateEnum
CREATE TYPE "MotifPerteProspect" AS ENUM ('PRIX', 'CONCURRENCE', 'PAS_DE_BESOIN', 'SANS_REPONSE', 'AUTRE');

-- CreateEnum
CREATE TYPE "TypeOpportunite" AS ENUM ('REFERENCEMENT', 'OP', 'MISE_EN_AVANT');

-- CreateEnum
CREATE TYPE "StatutOpportunite" AS ENUM ('OUVERTE', 'GAGNEE', 'PERDUE', 'ANNULEE');

-- DropForeignKey
ALTER TABLE "client_contacts" DROP CONSTRAINT "client_contacts_clientId_fkey";

-- DropForeignKey
ALTER TABLE "client_notes" DROP CONSTRAINT "client_notes_clientId_fkey";

-- DropForeignKey
ALTER TABLE "visites" DROP CONSTRAINT "visites_clientId_fkey";

-- AlterTable
ALTER TABLE "client_contacts" ADD COLUMN     "prospectId" UUID,
ALTER COLUMN "clientId" DROP NOT NULL;

-- AlterTable
ALTER TABLE "client_notes" ADD COLUMN     "prospectId" UUID,
ALTER COLUMN "clientId" DROP NOT NULL;

-- AlterTable
ALTER TABLE "visites" ADD COLUMN     "prospectId" UUID,
ALTER COLUMN "clientId" DROP NOT NULL;

-- CreateTable
CREATE TABLE "prospects" (
    "id" UUID NOT NULL,
    "raisonSociale" TEXT NOT NULL,
    "enseigne" TEXT NOT NULL,
    "adresse1" TEXT,
    "codePostal" TEXT,
    "ville" TEXT,
    "telephone" TEXT,
    "email" TEXT,
    "secteurId" UUID,
    "assignedToId" UUID,
    "createdById" UUID,
    "statut" "PipelineEtape" NOT NULL DEFAULT 'NOUVEAU',
    "probabilite" INTEGER NOT NULL DEFAULT 10,
    "potentielCaAnnuel" DECIMAL(14,2),
    "source" "SourceProspect",
    "motifPerte" "MotifPerteProspect",
    "clientId" UUID,
    "idApk" TEXT,
    "lastActivityAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "prospects_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "opportunites" (
    "id" UUID NOT NULL,
    "type" "TypeOpportunite" NOT NULL,
    "prospectId" UUID,
    "clientId" UUID,
    "libelle" TEXT,
    "valeurEstimee" DECIMAL(14,2),
    "statut" "StatutOpportunite" NOT NULL DEFAULT 'OUVERTE',
    "dateDebut" TIMESTAMP(3),
    "dateFin" TIMESTAMP(3),
    "assignedToId" UUID,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "opportunites_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "_OpportuniteArticles" (
    "A" UUID NOT NULL,
    "B" UUID NOT NULL,

    CONSTRAINT "_OpportuniteArticles_AB_pkey" PRIMARY KEY ("A","B")
);

-- CreateIndex
CREATE UNIQUE INDEX "prospects_clientId_key" ON "prospects"("clientId");

-- CreateIndex
CREATE UNIQUE INDEX "prospects_idApk_key" ON "prospects"("idApk");

-- CreateIndex
CREATE INDEX "prospects_secteurId_idx" ON "prospects"("secteurId");

-- CreateIndex
CREATE INDEX "prospects_assignedToId_idx" ON "prospects"("assignedToId");

-- CreateIndex
CREATE INDEX "prospects_statut_idx" ON "prospects"("statut");

-- CreateIndex
CREATE INDEX "opportunites_prospectId_idx" ON "opportunites"("prospectId");

-- CreateIndex
CREATE INDEX "opportunites_clientId_idx" ON "opportunites"("clientId");

-- CreateIndex
CREATE INDEX "opportunites_statut_idx" ON "opportunites"("statut");

-- CreateIndex
CREATE INDEX "_OpportuniteArticles_B_index" ON "_OpportuniteArticles"("B");

-- CreateIndex
CREATE INDEX "client_contacts_prospectId_idx" ON "client_contacts"("prospectId");

-- CreateIndex
CREATE INDEX "client_notes_prospectId_idx" ON "client_notes"("prospectId");

-- CreateIndex
CREATE INDEX "visites_prospectId_idx" ON "visites"("prospectId");

-- AddForeignKey
ALTER TABLE "client_contacts" ADD CONSTRAINT "client_contacts_clientId_fkey" FOREIGN KEY ("clientId") REFERENCES "clients"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "client_contacts" ADD CONSTRAINT "client_contacts_prospectId_fkey" FOREIGN KEY ("prospectId") REFERENCES "prospects"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "client_notes" ADD CONSTRAINT "client_notes_clientId_fkey" FOREIGN KEY ("clientId") REFERENCES "clients"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "client_notes" ADD CONSTRAINT "client_notes_prospectId_fkey" FOREIGN KEY ("prospectId") REFERENCES "prospects"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "visites" ADD CONSTRAINT "visites_clientId_fkey" FOREIGN KEY ("clientId") REFERENCES "clients"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "visites" ADD CONSTRAINT "visites_prospectId_fkey" FOREIGN KEY ("prospectId") REFERENCES "prospects"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "prospects" ADD CONSTRAINT "prospects_secteurId_fkey" FOREIGN KEY ("secteurId") REFERENCES "secteurs"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "prospects" ADD CONSTRAINT "prospects_assignedToId_fkey" FOREIGN KEY ("assignedToId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "prospects" ADD CONSTRAINT "prospects_createdById_fkey" FOREIGN KEY ("createdById") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "prospects" ADD CONSTRAINT "prospects_clientId_fkey" FOREIGN KEY ("clientId") REFERENCES "clients"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "opportunites" ADD CONSTRAINT "opportunites_prospectId_fkey" FOREIGN KEY ("prospectId") REFERENCES "prospects"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "opportunites" ADD CONSTRAINT "opportunites_clientId_fkey" FOREIGN KEY ("clientId") REFERENCES "clients"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "opportunites" ADD CONSTRAINT "opportunites_assignedToId_fkey" FOREIGN KEY ("assignedToId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "_OpportuniteArticles" ADD CONSTRAINT "_OpportuniteArticles_A_fkey" FOREIGN KEY ("A") REFERENCES "articles"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "_OpportuniteArticles" ADD CONSTRAINT "_OpportuniteArticles_B_fkey" FOREIGN KEY ("B") REFERENCES "opportunites"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Un contact / une note / une visite porte sur un magasin OU un prospect — jamais les deux, jamais aucun.
ALTER TABLE "client_contacts" ADD CONSTRAINT "client_contacts_client_ou_prospect"
  CHECK (("clientId" IS NULL) <> ("prospectId" IS NULL));
ALTER TABLE "client_notes" ADD CONSTRAINT "client_notes_client_ou_prospect"
  CHECK (("clientId" IS NULL) <> ("prospectId" IS NULL));
ALTER TABLE "visites" ADD CONSTRAINT "visites_client_ou_prospect"
  CHECK (("clientId" IS NULL) <> ("prospectId" IS NULL));
