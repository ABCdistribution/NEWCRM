-- DropIndex
DROP INDEX "users_regionId_idx";

-- AlterTable
ALTER TABLE "plannifications" ALTER COLUMN "dateDebut" DROP DEFAULT;

-- CreateTable
CREATE TABLE "commandes_apk" (
    "id" UUID NOT NULL,
    "idCommandeApk" VARCHAR(10) NOT NULL,
    "promoteurId" UUID NOT NULL,
    "clientId" UUID NOT NULL,
    "commentaire" TEXT,
    "dateCommande" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "commandes_apk_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "commande_apk_lignes" (
    "id" UUID NOT NULL,
    "commandeApkId" UUID NOT NULL,
    "ordre" INTEGER NOT NULL,
    "articleId" UUID NOT NULL,
    "quantite" INTEGER NOT NULL,
    "prixIndicatif" DECIMAL(14,4),

    CONSTRAINT "commande_apk_lignes_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "commandes_apk_idCommandeApk_key" ON "commandes_apk"("idCommandeApk");

-- CreateIndex
CREATE INDEX "commandes_apk_promoteurId_idx" ON "commandes_apk"("promoteurId");

-- CreateIndex
CREATE INDEX "commandes_apk_clientId_idx" ON "commandes_apk"("clientId");

-- CreateIndex
CREATE INDEX "commande_apk_lignes_articleId_idx" ON "commande_apk_lignes"("articleId");

-- CreateIndex
CREATE UNIQUE INDEX "commande_apk_lignes_commandeApkId_ordre_key" ON "commande_apk_lignes"("commandeApkId", "ordre");

-- AddForeignKey
ALTER TABLE "commandes_apk" ADD CONSTRAINT "commandes_apk_promoteurId_fkey" FOREIGN KEY ("promoteurId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "commandes_apk" ADD CONSTRAINT "commandes_apk_clientId_fkey" FOREIGN KEY ("clientId") REFERENCES "clients"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "commande_apk_lignes" ADD CONSTRAINT "commande_apk_lignes_commandeApkId_fkey" FOREIGN KEY ("commandeApkId") REFERENCES "commandes_apk"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "commande_apk_lignes" ADD CONSTRAINT "commande_apk_lignes_articleId_fkey" FOREIGN KEY ("articleId") REFERENCES "articles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
