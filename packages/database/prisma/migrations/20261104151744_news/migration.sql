-- CreateTable
CREATE TABLE "news" (
    "id" UUID NOT NULL,
    "titre" TEXT NOT NULL,
    "contenu" TEXT NOT NULL,
    "imageUrl" TEXT,
    "publiee" BOOLEAN NOT NULL DEFAULT false,
    "publieeAt" TIMESTAMP(3),
    "auteurId" UUID NOT NULL,
    "auteurNom" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "news_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "news_publiee_publieeAt_idx" ON "news"("publiee", "publieeAt");

-- CreateIndex
CREATE INDEX "news_deletedAt_idx" ON "news"("deletedAt");

-- CreateIndex
CREATE INDEX "news_auteurId_idx" ON "news"("auteurId");

-- AddForeignKey
ALTER TABLE "news" ADD CONSTRAINT "news_auteurId_fkey" FOREIGN KEY ("auteurId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
