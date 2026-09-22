-- CreateEnum
CREATE TYPE "Role" AS ENUM ('COMMERCIAL', 'CHEF_SECTEUR', 'ADMIN');

-- CreateEnum
CREATE TYPE "ImportSource" AS ENUM ('MIOS', 'AS400');

-- CreateEnum
CREATE TYPE "ImportStatus" AS ENUM ('PENDING', 'PROCESSING', 'SUCCESS', 'FAILED');

-- CreateTable
CREATE TABLE "users" (
    "id" UUID NOT NULL,
    "azureAdObjectId" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "displayName" TEXT NOT NULL,
    "role" "Role" NOT NULL DEFAULT 'COMMERCIAL',
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "secteurId" UUID,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "secteurs" (
    "id" UUID NOT NULL,
    "code" TEXT NOT NULL,
    "nom" TEXT NOT NULL,
    "managerId" UUID,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "secteurs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "clients" (
    "id" UUID NOT NULL,
    "codeAs400" TEXT NOT NULL,
    "enseigne" TEXT NOT NULL,
    "raisonSociale" TEXT NOT NULL,
    "adresse" TEXT,
    "codePostal" TEXT,
    "ville" TEXT,
    "pays" TEXT DEFAULT 'France',
    "telephone" TEXT,
    "email" TEXT,
    "actif" BOOLEAN NOT NULL DEFAULT true,
    "secteurId" UUID,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "clients_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "erp_import_logs" (
    "id" UUID NOT NULL,
    "fileName" TEXT NOT NULL,
    "source" "ImportSource" NOT NULL DEFAULT 'MIOS',
    "status" "ImportStatus" NOT NULL DEFAULT 'PENDING',
    "jobId" TEXT,
    "rowsTotal" INTEGER NOT NULL DEFAULT 0,
    "rowsOk" INTEGER NOT NULL DEFAULT 0,
    "rowsFailed" INTEGER NOT NULL DEFAULT 0,
    "fileSizeBytes" INTEGER,
    "errorMessage" TEXT,
    "startedAt" TIMESTAMP(3),
    "finishedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "erp_import_logs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "_ClientCommerciaux" (
    "A" UUID NOT NULL,
    "B" UUID NOT NULL,

    CONSTRAINT "_ClientCommerciaux_AB_pkey" PRIMARY KEY ("A","B")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_azureAdObjectId_key" ON "users"("azureAdObjectId");

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE UNIQUE INDEX "secteurs_code_key" ON "secteurs"("code");

-- CreateIndex
CREATE INDEX "secteurs_managerId_idx" ON "secteurs"("managerId");

-- CreateIndex
CREATE UNIQUE INDEX "clients_codeAs400_key" ON "clients"("codeAs400");

-- CreateIndex
CREATE INDEX "clients_secteurId_idx" ON "clients"("secteurId");

-- CreateIndex
CREATE INDEX "erp_import_logs_status_idx" ON "erp_import_logs"("status");

-- CreateIndex
CREATE INDEX "_ClientCommerciaux_B_index" ON "_ClientCommerciaux"("B");

-- AddForeignKey
ALTER TABLE "users" ADD CONSTRAINT "users_secteurId_fkey" FOREIGN KEY ("secteurId") REFERENCES "secteurs"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "secteurs" ADD CONSTRAINT "secteurs_managerId_fkey" FOREIGN KEY ("managerId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "clients" ADD CONSTRAINT "clients_secteurId_fkey" FOREIGN KEY ("secteurId") REFERENCES "secteurs"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "_ClientCommerciaux" ADD CONSTRAINT "_ClientCommerciaux_A_fkey" FOREIGN KEY ("A") REFERENCES "clients"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "_ClientCommerciaux" ADD CONSTRAINT "_ClientCommerciaux_B_fkey" FOREIGN KEY ("B") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
