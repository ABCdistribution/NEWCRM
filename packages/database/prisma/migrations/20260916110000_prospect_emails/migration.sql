-- Emails envoyés aux prospects (action « Envoyer un mail » de la fiche / mobile).
CREATE TABLE "prospect_emails" (
    "id" UUID NOT NULL,
    "prospectId" UUID NOT NULL,
    "auteurId" UUID,
    "dateEmail" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "destinataire" TEXT,
    "sujet" TEXT,
    "commentaire" TEXT,
    "idApk" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "prospect_emails_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "prospect_emails_idApk_key" ON "prospect_emails"("idApk");
CREATE INDEX "prospect_emails_prospectId_idx" ON "prospect_emails"("prospectId");
CREATE INDEX "prospect_emails_auteurId_idx" ON "prospect_emails"("auteurId");

ALTER TABLE "prospect_emails" ADD CONSTRAINT "prospect_emails_prospectId_fkey" FOREIGN KEY ("prospectId") REFERENCES "prospects"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "prospect_emails" ADD CONSTRAINT "prospect_emails_auteurId_fkey" FOREIGN KEY ("auteurId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
