-- Module 3 : Catalogue produits

-- Tables
CREATE TABLE "marques" (
    "id" UUID NOT NULL,
    "code" TEXT NOT NULL,
    "nom" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "marques_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "marques_code_key" ON "marques"("code");

CREATE TABLE "gammes" (
    "id" UUID NOT NULL,
    "code" TEXT NOT NULL,
    "nom" TEXT NOT NULL,
    "marqueId" UUID,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "gammes_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "gammes_code_key" ON "gammes"("code");
CREATE INDEX "gammes_marqueId_idx" ON "gammes"("marqueId");

CREATE TABLE "familles" (
    "id" UUID NOT NULL,
    "code" TEXT NOT NULL,
    "nom" TEXT NOT NULL,
    "gammeId" UUID,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "familles_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "familles_code_key" ON "familles"("code");
CREATE INDEX "familles_gammeId_idx" ON "familles"("gammeId");

CREATE TABLE "articles" (
    "id" UUID NOT NULL,
    "codeAs400" TEXT NOT NULL,
    "libelle" TEXT NOT NULL,
    "gencode" TEXT,
    "idIta" TEXT,
    "marqueId" UUID,
    "gammeId" UUID,
    "familleId" UUID,
    "familleAcd" TEXT,
    "sousFamilleAcd" TEXT,
    "famillePlan" TEXT,
    "codeTva" TEXT,
    "pcb" INTEGER,
    "statut" TEXT,
    "sousStatut" TEXT,
    "retourAutorise" BOOLEAN NOT NULL DEFAULT false,
    "details" TEXT,
    "avantages" TEXT,
    "stock" INTEGER NOT NULL DEFAULT 0,
    "actif" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),
    CONSTRAINT "articles_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "articles_codeAs400_key" ON "articles"("codeAs400");
CREATE INDEX "articles_marqueId_idx" ON "articles"("marqueId");
CREATE INDEX "articles_gammeId_idx" ON "articles"("gammeId");
CREATE INDEX "articles_familleId_idx" ON "articles"("familleId");

CREATE TABLE "tarifs" (
    "id" UUID NOT NULL,
    "articleId" UUID NOT NULL,
    "montant" DECIMAL(12,2) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),
    CONSTRAINT "tarifs_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "tarifs_articleId_idx" ON "tarifs"("articleId");

CREATE TABLE "article_switchs" (
    "id" UUID NOT NULL,
    "articleId" UUID NOT NULL,
    "cibleId" UUID NOT NULL,
    "seuil" INTEGER,
    "creeParId" UUID,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "article_switchs_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "article_switchs_articleId_idx" ON "article_switchs"("articleId");
CREATE INDEX "article_switchs_cibleId_idx" ON "article_switchs"("cibleId");
CREATE INDEX "article_switchs_creeParId_idx" ON "article_switchs"("creeParId");

CREATE TABLE "promos" (
    "id" UUID NOT NULL,
    "articleId" UUID NOT NULL,
    "libelle" TEXT,
    "dateDebut" TIMESTAMP(3),
    "dateFin" TIMESTAMP(3),
    "actif" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "promos_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "promos_articleId_idx" ON "promos"("articleId");

CREATE TABLE "pem_articles" (
    "id" UUID NOT NULL,
    "articleId" UUID NOT NULL,
    "actif" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "pem_articles_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "pem_articles_articleId_idx" ON "pem_articles"("articleId");

CREATE TABLE "strat_pems" (
    "id" UUID NOT NULL,
    "nom" TEXT NOT NULL,
    "actif" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "strat_pems_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "strat_pem_lignes" (
    "id" UUID NOT NULL,
    "stratPemId" UUID NOT NULL,
    "articleId" UUID,
    "ordre" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "strat_pem_lignes_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "strat_pem_lignes_stratPemId_idx" ON "strat_pem_lignes"("stratPemId");
CREATE INDEX "strat_pem_lignes_articleId_idx" ON "strat_pem_lignes"("articleId");

-- Clés étrangères
ALTER TABLE "gammes" ADD CONSTRAINT "gammes_marqueId_fkey" FOREIGN KEY ("marqueId") REFERENCES "marques"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "familles" ADD CONSTRAINT "familles_gammeId_fkey" FOREIGN KEY ("gammeId") REFERENCES "gammes"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "articles" ADD CONSTRAINT "articles_marqueId_fkey" FOREIGN KEY ("marqueId") REFERENCES "marques"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "articles" ADD CONSTRAINT "articles_gammeId_fkey" FOREIGN KEY ("gammeId") REFERENCES "gammes"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "articles" ADD CONSTRAINT "articles_familleId_fkey" FOREIGN KEY ("familleId") REFERENCES "familles"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "tarifs" ADD CONSTRAINT "tarifs_articleId_fkey" FOREIGN KEY ("articleId") REFERENCES "articles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "article_switchs" ADD CONSTRAINT "article_switchs_articleId_fkey" FOREIGN KEY ("articleId") REFERENCES "articles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "article_switchs" ADD CONSTRAINT "article_switchs_cibleId_fkey" FOREIGN KEY ("cibleId") REFERENCES "articles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "article_switchs" ADD CONSTRAINT "article_switchs_creeParId_fkey" FOREIGN KEY ("creeParId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "promos" ADD CONSTRAINT "promos_articleId_fkey" FOREIGN KEY ("articleId") REFERENCES "articles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "pem_articles" ADD CONSTRAINT "pem_articles_articleId_fkey" FOREIGN KEY ("articleId") REFERENCES "articles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "strat_pem_lignes" ADD CONSTRAINT "strat_pem_lignes_stratPemId_fkey" FOREIGN KEY ("stratPemId") REFERENCES "strat_pems"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "strat_pem_lignes" ADD CONSTRAINT "strat_pem_lignes_articleId_fkey" FOREIGN KEY ("articleId") REFERENCES "articles"("id") ON DELETE SET NULL ON UPDATE CASCADE;
