-- =====================================================================
-- Seed de DÉMO — remplit les colonnes vides de la table « Mes magasins »
-- (CS, niveau, périodicité, dernière visite, Δ N-1) quand l'import ERP ne
-- fournit pas ces données. Ré-exécutable (garde-fous anti-doublons).
--   docker exec -i crm-abc-postgres psql -U crm -d crm < packages/database/seed-demo.sql
-- =====================================================================

-- 1) CS — lie chaque magasin à son commercial (User.idRepr ↔ idCommercial1/2).
--    Vraie donnée (pas du fake) : le join _ClientCommerciaux n'était pas peuplé.
INSERT INTO "_ClientCommerciaux" ("A", "B")
SELECT DISTINCT c.id, u.id
FROM clients c
JOIN users u ON u."idRepr" IS NOT NULL AND (
      u."idRepr" = c."idCommercial1"
   OR u."idRepr" = lpad(c."idCommercial1", 3, '0')
   OR ltrim(u."idRepr", '0') = ltrim(c."idCommercial1", '0')
   OR u."idRepr" = c."idCommercial2"
   OR u."idRepr" = lpad(c."idCommercial2", 3, '0')
   OR ltrim(u."idRepr", '0') = ltrim(c."idCommercial2", '0')
)
WHERE c."deletedAt" IS NULL
ON CONFLICT DO NOTHING;

-- 2) Niveau CRM A→G (aléatoire) sur les magasins sans niveau.
UPDATE clients
SET "niveauClass" = (ARRAY['A','B','B','C','C','C','D','D','E','F','G'])[1 + floor(random() * 11)::int]::"NiveauClass"
WHERE "deletedAt" IS NULL AND "niveauClass" IS NULL;

-- 3) Périodicité de visite (aléatoire) pour les magasins qui n'en ont pas.
INSERT INTO client_periodicites (id, "clientId", "periodiciteId", "createdAt", "updatedAt")
SELECT gen_random_uuid(), c.id, p.id, now(), now()
FROM clients c
JOIN LATERAL (SELECT id FROM periodicites ORDER BY random() LIMIT 1) p ON true
WHERE c."deletedAt" IS NULL
  AND NOT EXISTS (SELECT 1 FROM client_periodicites cp WHERE cp."clientId" = c.id AND cp."deletedAt" IS NULL);

-- 4) Dernière visite (fake) : une visite datée au hasard des 90 derniers jours,
--    par le commercial du magasin, pour les magasins qui n'ont aucune visite.
INSERT INTO visites (id, "promoteurId", "clientId", pem, "createdAt", "updatedAt")
SELECT gen_random_uuid(), u.id, c.id, false,
       now() - (floor(random() * 90))::int * interval '1 day', now()
FROM clients c
JOIN LATERAL (SELECT cc."B" AS id FROM "_ClientCommerciaux" cc WHERE cc."A" = c.id LIMIT 1) u ON true
WHERE c."deletedAt" IS NULL
  AND NOT EXISTS (SELECT 1 FROM visites v WHERE v."clientId" = c.id);

-- 5) Δ vs N-1 (fake) : une commande « N-1 » (sept. année précédente) pour chaque
--    magasin ayant commandé ce mois-ci, avec un montant à ±30 % du CA courant.
WITH ca_courant AS (
  SELECT co."clientId", SUM(cl.montant) AS ca
  FROM commandes co JOIN commande_lignes cl ON cl."commandeId" = co.id
  WHERE co."dateAnnulation" IS NULL
    AND co."dateCommande" >= date_trunc('month', now())
    AND co."dateCommande" <  date_trunc('month', now()) + interval '1 month'
    AND co."clientId" IS NOT NULL
  GROUP BY 1
),
nouvelles AS (
  INSERT INTO commandes (id, numero, "clientId", "idRepr", "typeCmd", "dateCommande", "createdAt", "updatedAt")
  SELECT gen_random_uuid(),
         'SEEDN1-' || substr(cc."clientId"::text, 1, 8),
         cc."clientId", c."idCommercial1", 'N', (date_trunc('month', now()) - interval '1 year' + interval '14 days'),
         now(), now()
  FROM ca_courant cc JOIN clients c ON c.id = cc."clientId"
  WHERE NOT EXISTS (
    SELECT 1 FROM commandes x WHERE x.numero = 'SEEDN1-' || substr(cc."clientId"::text, 1, 8)
  )
  RETURNING id, "clientId"
)
INSERT INTO commande_lignes (id, "commandeId", "noLigne", "quantite", "montant", "createdAt", "updatedAt")
SELECT gen_random_uuid(), n.id, '1', 1,
       round((cc.ca * (0.7 + random() * 0.6))::numeric, 2), now(), now()
FROM nouvelles n JOIN ca_courant cc ON cc."clientId" = n."clientId";

-- Récapitulatif
SELECT
  (SELECT count(*) FROM "_ClientCommerciaux") AS liens_cs,
  (SELECT count(*) FROM clients WHERE "niveauClass" IS NOT NULL) AS clients_niveau,
  (SELECT count(*) FROM client_periodicites WHERE "deletedAt" IS NULL) AS periodicites,
  (SELECT count(*) FROM visites) AS visites,
  (SELECT count(*) FROM commandes WHERE numero LIKE 'SEEDN1-%') AS commandes_n1;

-- 6) Tournées (fake) : jusqu'à 14 visites planifiées par commercial, réparties
--    sur la semaine courante + la suivante (hors dimanche), certaines déjà faites.
INSERT INTO plannings (id, "promoteurId", "clientId", "datePassage", fait, "createdAt", "updatedAt")
SELECT gen_random_uuid(), t."B", t."A", d.day::timestamp,
       (d.day < current_date AND random() < 0.6), now(), now()
FROM (
  SELECT cc."A", cc."B", row_number() OVER (PARTITION BY cc."B" ORDER BY random()) AS rn
  FROM "_ClientCommerciaux" cc
) t
JOIN LATERAL (SELECT (date_trunc('week', now())::date + (floor(random() * 12))::int) AS day) d ON true
WHERE t.rn <= 14
  AND EXTRACT(DOW FROM d.day) <> 0
  AND NOT EXISTS (
    SELECT 1 FROM plannings p
    WHERE p."promoteurId" = t."B" AND p."clientId" = t."A" AND p."datePassage"::date = d.day
  );

SELECT count(*) AS plannings_total,
       count(*) FILTER (WHERE "datePassage" >= date_trunc('week', now())
                         AND "datePassage" < date_trunc('week', now()) + interval '14 days') AS plannings_2sem
FROM plannings;

-- 7) Détail des visites (fake) : DN, PEM, motif sur les visites sans relevé.
UPDATE visites SET
  "dnAbc" = 5 + floor(random()*45)::int,
  "dnConcurrence" = floor(random()*30)::int,
  "dnGondoleHaute" = floor(random()*15)::int,
  "dnGondoleBasse" = floor(random()*15)::int,
  pem = random() < 0.4,
  motif = (ARRAY['Planifiée','Passage opportunité','Appel client','Urgence'])[1 + floor(random()*4)::int]
WHERE "dnAbc" IS NULL;
