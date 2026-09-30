-- Prévision & validation hebdomadaire du planning d'activité.
CREATE TABLE "planning_semaines" (
  "id" UUID NOT NULL,
  "userId" UUID NOT NULL,
  "semaine" DATE NOT NULL,
  "prevuAt" TIMESTAMP(3),
  "valideAt" TIMESTAMP(3),
  "nbEtapesPrevues" INTEGER,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "planning_semaines_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "planning_semaines_userId_semaine_key" ON "planning_semaines"("userId", "semaine");
ALTER TABLE "planning_semaines" ADD CONSTRAINT "planning_semaines_userId_fkey"
  FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
