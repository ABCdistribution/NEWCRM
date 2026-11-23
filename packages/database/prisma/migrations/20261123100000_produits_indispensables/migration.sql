-- Produits indispensables par enseigne (centrale) et relevé présent / absent en visite.
-- Additive : deux nouvelles tables, aucune table existante modifiée.
-- Retour arrière : DROP TABLE "visite_indispensables"; DROP TABLE "produits_indispensables";
-- CreateTable
CREATE TABLE "produits_indispensables" (
    "id" UUID NOT NULL,
    "centraleId" UUID NOT NULL,
    "articleId" UUID NOT NULL,
    "ordre" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "produits_indispensables_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "visite_indispensables" (
    "id" UUID NOT NULL,
    "visiteId" UUID NOT NULL,
    "articleId" UUID NOT NULL,
    "present" BOOLEAN NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "visite_indispensables_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "produits_indispensables_centraleId_idx" ON "produits_indispensables"("centraleId");

-- CreateIndex
CREATE INDEX "produits_indispensables_articleId_idx" ON "produits_indispensables"("articleId");

-- CreateIndex
CREATE UNIQUE INDEX "produits_indispensables_centraleId_articleId_key" ON "produits_indispensables"("centraleId", "articleId");

-- CreateIndex
CREATE INDEX "visite_indispensables_visiteId_idx" ON "visite_indispensables"("visiteId");

-- CreateIndex
CREATE INDEX "visite_indispensables_articleId_idx" ON "visite_indispensables"("articleId");

-- CreateIndex
CREATE UNIQUE INDEX "visite_indispensables_visiteId_articleId_key" ON "visite_indispensables"("visiteId", "articleId");

-- AddForeignKey
ALTER TABLE "produits_indispensables" ADD CONSTRAINT "produits_indispensables_centraleId_fkey" FOREIGN KEY ("centraleId") REFERENCES "centrales"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "produits_indispensables" ADD CONSTRAINT "produits_indispensables_articleId_fkey" FOREIGN KEY ("articleId") REFERENCES "articles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "visite_indispensables" ADD CONSTRAINT "visite_indispensables_visiteId_fkey" FOREIGN KEY ("visiteId") REFERENCES "visites"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "visite_indispensables" ADD CONSTRAINT "visite_indispensables_articleId_fkey" FOREIGN KEY ("articleId") REFERENCES "articles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

