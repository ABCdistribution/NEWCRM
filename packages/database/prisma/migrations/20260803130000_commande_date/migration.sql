-- Date de commande (AAANN/MMANN/JJANN, distincte de l'annulation checky/m/d)
ALTER TABLE "commandes" ADD COLUMN "dateCommande" TIMESTAMP(3);
