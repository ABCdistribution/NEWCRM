-- Commandes ERP (en-tête + lignes)

CREATE TABLE "commandes" (
    "id" UUID NOT NULL,
    "numero" TEXT NOT NULL,
    "clientId" UUID,
    "raisonSocialeCmd" TEXT,
    "idRepr" TEXT,
    "typeCmd" TEXT,
    "idCommandeApk" TEXT,
    "dateAnnulation" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "commandes_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "commandes_numero_key" ON "commandes"("numero");
CREATE INDEX "commandes_clientId_idx" ON "commandes"("clientId");
CREATE INDEX "commandes_idCommandeApk_idx" ON "commandes"("idCommandeApk");

CREATE TABLE "commande_lignes" (
    "id" UUID NOT NULL,
    "commandeId" UUID NOT NULL,
    "noLigne" TEXT NOT NULL,
    "articleId" UUID,
    "libelleArticle" TEXT,
    "quantite" DECIMAL(14,4) NOT NULL,
    "montant" DECIMAL(14,4) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "commande_lignes_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "commande_lignes_commandeId_noLigne_key" ON "commande_lignes"("commandeId", "noLigne");
CREATE INDEX "commande_lignes_commandeId_idx" ON "commande_lignes"("commandeId");
CREATE INDEX "commande_lignes_articleId_idx" ON "commande_lignes"("articleId");

ALTER TABLE "commandes" ADD CONSTRAINT "commandes_clientId_fkey" FOREIGN KEY ("clientId") REFERENCES "clients"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "commande_lignes" ADD CONSTRAINT "commande_lignes_commandeId_fkey" FOREIGN KEY ("commandeId") REFERENCES "commandes"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "commande_lignes" ADD CONSTRAINT "commande_lignes_articleId_fkey" FOREIGN KEY ("articleId") REFERENCES "articles"("id") ON DELETE SET NULL ON UPDATE CASCADE;
