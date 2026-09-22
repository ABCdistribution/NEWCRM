-- Module 1 : Structure commerciale (Region, hiérarchie DR, rôles)

-- Nouveaux rôles (repris des profils legacy secu_profile)
ALTER TYPE "Role" ADD VALUE 'DIRECTEUR_REGIONAL';
ALTER TYPE "Role" ADD VALUE 'DIRECTION';
ALTER TYPE "Role" ADD VALUE 'ADV';
ALTER TYPE "Role" ADD VALUE 'MARKETING';

-- Table regions
CREATE TABLE "regions" (
    "id" UUID NOT NULL,
    "code" TEXT NOT NULL,
    "nom" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "regions_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "regions_code_key" ON "regions"("code");

-- secteurs : rattachement à une région
ALTER TABLE "secteurs" ADD COLUMN "regionId" UUID;
CREATE INDEX "secteurs_regionId_idx" ON "secteurs"("regionId");
ALTER TABLE "secteurs" ADD CONSTRAINT "secteurs_regionId_fkey" FOREIGN KEY ("regionId") REFERENCES "regions"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- users : code représentant, poste, hiérarchie DR
ALTER TABLE "users" ADD COLUMN "idRepr" TEXT;
ALTER TABLE "users" ADD COLUMN "poste" TEXT;
ALTER TABLE "users" ADD COLUMN "directeurId" UUID;
CREATE UNIQUE INDEX "users_idRepr_key" ON "users"("idRepr");
CREATE INDEX "users_secteurId_idx" ON "users"("secteurId");
CREATE INDEX "users_directeurId_idx" ON "users"("directeurId");
ALTER TABLE "users" ADD CONSTRAINT "users_directeurId_fkey" FOREIGN KEY ("directeurId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
