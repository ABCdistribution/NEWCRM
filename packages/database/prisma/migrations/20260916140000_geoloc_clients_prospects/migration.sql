-- Coordonnées GPS (géocodage BAN des adresses) sur les magasins et prospects.
ALTER TABLE "clients" ADD COLUMN "latitude" DOUBLE PRECISION;
ALTER TABLE "clients" ADD COLUMN "longitude" DOUBLE PRECISION;
ALTER TABLE "prospects" ADD COLUMN "latitude" DOUBLE PRECISION;
ALTER TABLE "prospects" ADD COLUMN "longitude" DOUBLE PRECISION;
