-- Journal des appels et emails vers les magasins (clients) — même modèle que
-- les prospects, affiché dans la gestion des magasins secteur (Helios).
CREATE TABLE "client_appels" (
    "id" UUID NOT NULL,
    "clientId" UUID NOT NULL,
    "auteurId" UUID,
    "dateAppel" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "dureeSec" INTEGER,
    "resultat" "ResultatAppel" NOT NULL DEFAULT 'REPONDU',
    "commentaire" TEXT,
    "idApk" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "deletedAt" TIMESTAMP(3),
    CONSTRAINT "client_appels_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "client_appels_idApk_key" ON "client_appels"("idApk");
CREATE INDEX "client_appels_clientId_idx" ON "client_appels"("clientId");
CREATE INDEX "client_appels_auteurId_idx" ON "client_appels"("auteurId");
ALTER TABLE "client_appels" ADD CONSTRAINT "client_appels_clientId_fkey" FOREIGN KEY ("clientId") REFERENCES "clients"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "client_appels" ADD CONSTRAINT "client_appels_auteurId_fkey" FOREIGN KEY ("auteurId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE TABLE "client_emails" (
    "id" UUID NOT NULL,
    "clientId" UUID NOT NULL,
    "auteurId" UUID,
    "dateEmail" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "destinataire" TEXT,
    "sujet" TEXT,
    "commentaire" TEXT,
    "idApk" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "deletedAt" TIMESTAMP(3),
    CONSTRAINT "client_emails_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "client_emails_idApk_key" ON "client_emails"("idApk");
CREATE INDEX "client_emails_clientId_idx" ON "client_emails"("clientId");
CREATE INDEX "client_emails_auteurId_idx" ON "client_emails"("auteurId");
ALTER TABLE "client_emails" ADD CONSTRAINT "client_emails_clientId_fkey" FOREIGN KEY ("clientId") REFERENCES "clients"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "client_emails" ADD CONSTRAINT "client_emails_auteurId_fkey" FOREIGN KEY ("auteurId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
