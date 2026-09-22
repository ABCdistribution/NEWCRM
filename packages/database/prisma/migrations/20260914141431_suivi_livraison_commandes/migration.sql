-- CreateEnum
CREATE TYPE "StatutLivraison" AS ENUM ('EN_PREPARATION', 'EXPEDIEE', 'LIVREE_PARTIELLE', 'LIVREE');

-- AlterTable
ALTER TABLE "commandes" ADD COLUMN     "commentaireLivraison" TEXT,
ADD COLUMN     "dateExpedition" TIMESTAMP(3),
ADD COLUMN     "dateLivraison" TIMESTAMP(3),
ADD COLUMN     "noSuivi" TEXT,
ADD COLUMN     "statutLivraison" "StatutLivraison" NOT NULL DEFAULT 'EN_PREPARATION',
ADD COLUMN     "transporteur" TEXT;

-- CreateIndex
CREATE INDEX "commandes_statutLivraison_idx" ON "commandes"("statutLivraison");
