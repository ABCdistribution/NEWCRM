-- Module 2 : Satellites Client (périodicités, contacts, notes)

-- Nomenclature périodicités
CREATE TABLE "periodicites" (
    "id" UUID NOT NULL,
    "code" INTEGER,
    "libelle" TEXT NOT NULL,
    "actif" BOOLEAN NOT NULL DEFAULT true,

    CONSTRAINT "periodicites_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "periodicites_code_key" ON "periodicites"("code");

-- Contacts d'un magasin
CREATE TABLE "client_contacts" (
    "id" UUID NOT NULL,
    "clientId" UUID NOT NULL,
    "prenom" TEXT,
    "nom" TEXT NOT NULL,
    "poste" TEXT,
    "typePoste" TEXT,
    "fixe" TEXT,
    "portable" TEXT,
    "mail" TEXT,
    "creeParId" UUID,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "client_contacts_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "client_contacts_clientId_idx" ON "client_contacts"("clientId");
CREATE INDEX "client_contacts_creeParId_idx" ON "client_contacts"("creeParId");

-- Notes terrain
CREATE TABLE "client_notes" (
    "id" UUID NOT NULL,
    "clientId" UUID NOT NULL,
    "remarque" TEXT NOT NULL,
    "idApk" TEXT,
    "auteurId" UUID,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "client_notes_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "client_notes_clientId_idx" ON "client_notes"("clientId");
CREATE INDEX "client_notes_auteurId_idx" ON "client_notes"("auteurId");

-- Périodicité affectée à un client
CREATE TABLE "client_periodicites" (
    "id" UUID NOT NULL,
    "clientId" UUID NOT NULL,
    "periodiciteId" UUID NOT NULL,
    "affecteParId" UUID,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "client_periodicites_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "client_periodicites_clientId_idx" ON "client_periodicites"("clientId");
CREATE INDEX "client_periodicites_periodiciteId_idx" ON "client_periodicites"("periodiciteId");

-- Clés étrangères
ALTER TABLE "client_contacts" ADD CONSTRAINT "client_contacts_clientId_fkey" FOREIGN KEY ("clientId") REFERENCES "clients"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "client_contacts" ADD CONSTRAINT "client_contacts_creeParId_fkey" FOREIGN KEY ("creeParId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "client_notes" ADD CONSTRAINT "client_notes_clientId_fkey" FOREIGN KEY ("clientId") REFERENCES "clients"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "client_notes" ADD CONSTRAINT "client_notes_auteurId_fkey" FOREIGN KEY ("auteurId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "client_periodicites" ADD CONSTRAINT "client_periodicites_clientId_fkey" FOREIGN KEY ("clientId") REFERENCES "clients"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "client_periodicites" ADD CONSTRAINT "client_periodicites_periodiciteId_fkey" FOREIGN KEY ("periodiciteId") REFERENCES "periodicites"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "client_periodicites" ADD CONSTRAINT "client_periodicites_affecteParId_fkey" FOREIGN KEY ("affecteParId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
