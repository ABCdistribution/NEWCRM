-- Module 4 : Terrain (visites & planning)

-- Enum type de DN
CREATE TYPE "TypeDn" AS ENUM ('ABC', 'CONCURRENCE');

-- Tables
CREATE TABLE "visites" (
    "id" UUID NOT NULL,
    "promoteurId" UUID NOT NULL,
    "clientId" UUID NOT NULL,
    "idApk" TEXT,
    "pmcEtat" TEXT,
    "pmcCommentaire" TEXT,
    "dnAbc" INTEGER,
    "dnConcurrence" INTEGER,
    "pem" BOOLEAN NOT NULL DEFAULT false,
    "queueDate" TIMESTAMP(3),
    "alerteRaison" TEXT,
    "alerteObs" TEXT,
    "visiteLieeId" UUID,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),
    CONSTRAINT "visites_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "visites_promoteurId_idx" ON "visites"("promoteurId");
CREATE INDEX "visites_clientId_idx" ON "visites"("clientId");
CREATE INDEX "visites_visiteLieeId_idx" ON "visites"("visiteLieeId");

CREATE TABLE "visite_dns" (
    "id" UUID NOT NULL,
    "visiteId" UUID NOT NULL,
    "type" "TypeDn" NOT NULL,
    "marque" TEXT,
    "gamme" TEXT,
    "metrage" DECIMAL(10,2),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "visite_dns_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "visite_dns_visiteId_idx" ON "visite_dns"("visiteId");

CREATE TABLE "visite_photos" (
    "id" UUID NOT NULL,
    "visiteId" UUID NOT NULL,
    "fichier" TEXT NOT NULL,
    "taille" INTEGER,
    "idVisiteApk" TEXT,
    "appName" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "visite_photos_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "visite_photos_visiteId_idx" ON "visite_photos"("visiteId");

CREATE TABLE "visite_steps" (
    "id" UUID NOT NULL,
    "visiteId" UUID NOT NULL,
    "etape" TEXT,
    "horodatage" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "visite_steps_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "visite_steps_visiteId_idx" ON "visite_steps"("visiteId");

CREATE TABLE "visite_promos" (
    "id" UUID NOT NULL,
    "visiteId" UUID NOT NULL,
    "articleId" UUID,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "visite_promos_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "visite_promos_visiteId_idx" ON "visite_promos"("visiteId");
CREATE INDEX "visite_promos_articleId_idx" ON "visite_promos"("articleId");

CREATE TABLE "plannifications" (
    "id" UUID NOT NULL,
    "promoteurId" UUID NOT NULL,
    "clientId" UUID NOT NULL,
    "jours" TEXT,
    "recurrence" INTEGER,
    "semaineDebut" INTEGER,
    "annee" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),
    CONSTRAINT "plannifications_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "plannifications_promoteurId_idx" ON "plannifications"("promoteurId");
CREATE INDEX "plannifications_clientId_idx" ON "plannifications"("clientId");

CREATE TABLE "plannings" (
    "id" UUID NOT NULL,
    "promoteurId" UUID NOT NULL,
    "clientId" UUID NOT NULL,
    "datePassage" TIMESTAMP(3) NOT NULL,
    "fait" BOOLEAN NOT NULL DEFAULT false,
    "raison" TEXT,
    "plannificationId" UUID,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),
    CONSTRAINT "plannings_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "plannings_promoteurId_idx" ON "plannings"("promoteurId");
CREATE INDEX "plannings_clientId_idx" ON "plannings"("clientId");
CREATE INDEX "plannings_plannificationId_idx" ON "plannings"("plannificationId");

CREATE TABLE "tournees" (
    "id" UUID NOT NULL,
    "promoteurId" UUID NOT NULL,
    "clientId" UUID NOT NULL,
    "jours" TEXT,
    "semaines" TEXT,
    "semaineDebut" INTEGER,
    "annee" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),
    CONSTRAINT "tournees_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "tournees_promoteurId_idx" ON "tournees"("promoteurId");
CREATE INDEX "tournees_clientId_idx" ON "tournees"("clientId");

-- Clés étrangères
ALTER TABLE "visites" ADD CONSTRAINT "visites_promoteurId_fkey" FOREIGN KEY ("promoteurId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "visites" ADD CONSTRAINT "visites_clientId_fkey" FOREIGN KEY ("clientId") REFERENCES "clients"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "visites" ADD CONSTRAINT "visites_visiteLieeId_fkey" FOREIGN KEY ("visiteLieeId") REFERENCES "visites"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "visite_dns" ADD CONSTRAINT "visite_dns_visiteId_fkey" FOREIGN KEY ("visiteId") REFERENCES "visites"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "visite_photos" ADD CONSTRAINT "visite_photos_visiteId_fkey" FOREIGN KEY ("visiteId") REFERENCES "visites"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "visite_steps" ADD CONSTRAINT "visite_steps_visiteId_fkey" FOREIGN KEY ("visiteId") REFERENCES "visites"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "visite_promos" ADD CONSTRAINT "visite_promos_visiteId_fkey" FOREIGN KEY ("visiteId") REFERENCES "visites"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "visite_promos" ADD CONSTRAINT "visite_promos_articleId_fkey" FOREIGN KEY ("articleId") REFERENCES "articles"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "plannings" ADD CONSTRAINT "plannings_promoteurId_fkey" FOREIGN KEY ("promoteurId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "plannings" ADD CONSTRAINT "plannings_clientId_fkey" FOREIGN KEY ("clientId") REFERENCES "clients"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "plannings" ADD CONSTRAINT "plannings_plannificationId_fkey" FOREIGN KEY ("plannificationId") REFERENCES "plannifications"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "plannifications" ADD CONSTRAINT "plannifications_promoteurId_fkey" FOREIGN KEY ("promoteurId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "plannifications" ADD CONSTRAINT "plannifications_clientId_fkey" FOREIGN KEY ("clientId") REFERENCES "clients"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "tournees" ADD CONSTRAINT "tournees_promoteurId_fkey" FOREIGN KEY ("promoteurId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "tournees" ADD CONSTRAINT "tournees_clientId_fkey" FOREIGN KEY ("clientId") REFERENCES "clients"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
