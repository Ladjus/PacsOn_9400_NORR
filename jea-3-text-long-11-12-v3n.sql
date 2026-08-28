-- Jeeves extract article data.
-- Singelartikel, behåller artikelnummer ar.extra4 = 11

/* Change log
v.1: Initial version. CTE cte_artnr for artnr synched from jea-2-mara-makt-mean-11-12-v3.sql. Refer:
     dev-ecom-3-text-long-11-12-v4.sql
v.2w: !!!PacsOn Väst 9100 only!!!
     Add CTE cte_artnr_west, refer jea-2-mara-makt-mean-11-12-v4w.sql
     Column MARA_RUN_ID use fixed value 'WEST'. Problem w date is that same article may get multiple records with different dates, then it's a mess.
v.3n: !!!PacsOn North 9400 only!!!
     !!! Fork from jea-3-text-long-11-12-v2w.sql to jea-3-text-long-11-12-v3n.sql !!!
     Add CTE cte_artnr_north
     Column MARA_RUN_ID fixed value 'NORTH' (was: WEST).
     WHERE clauses changed.
*/


-- Query 1/2
-- Product (mandatory) [S_MARA]
WITH cte_artnr AS (
  SELECT artnr
  FROM ar
  WHERE
    ForetagKod = 2000  -- Mall
    AND extra4 IN (11, 12)
),
cte_artnr_west AS (  -- Add v.2w.
  SELECT ar_2000.artnr
  FROM ar AS ar_2000
    LEFT OUTER JOIN ar AS ar_9100
      ON ar_2000.artnr = ar_9100.artnr
      AND ar_9100.ForetagKod = 9100  -- Väst
  WHERE
    ar_2000.ForetagKod = 2000  -- Mall
    AND ar_2000.extra4 IN (11, 12)
    AND (ar_2000.q_saps4_sortiment IN ('A', 'B')  -- A/B-sortiment: alla artiklar.
         OR (ar_2000.q_saps4_sortiment IN ('C') AND ar_9100.artnr IS NOT NULL))  -- C-sortiment: endast artiklar som finns i Väst 9100.
),
cte_artnr_north AS (  -- Add v.3n.
  SELECT ar_2000.artnr
  FROM ar AS ar_2000
    LEFT OUTER JOIN ar AS ar_9400
      ON ar_2000.artnr = ar_9400.artnr
      AND ar_9400.ForetagKod = 9400  -- Norr
  WHERE
    ar_2000.ForetagKod = 2000  -- Mall
    AND ar_2000.extra4 IN (11, 12)
    -- A/B-sortiment: inga artiklar, de har redan lång-text på global nivå.
    AND (ar_2000.q_saps4_sortiment IN ('C') AND ar_9400.artnr IS NOT NULL)  -- C-sortiment: endast artiklar som finns i Norr 9400.
)
SELECT
  ar.artnr AS AR_ArtNr,  -- Jeeves "Artikel ID"
  ar.artbeskrspec AS MARA_PRODUCT,  -- SAP Product. Jeeves "Artikelnr"
  'NORTH' AS MARA_RUN_ID  -- Change v.3n.
FROM ar
WHERE
  ar.foretagkod = 2000  -- Mall
--  AND ar.artnr IN (SELECT artnr FROM cte_artnr)  -- AR.extra4 subquery. Remove v.2w.
--  AND ar.artnr IN (SELECT artnr FROM cte_artnr_west)  -- AR.extra4 subquery. Add v.2w. Remove v.3n.
  AND ar.artnr IN (SELECT artnr FROM cte_artnr_north)  -- AR.extra4 subquery. Add v.3n.
ORDER BY 2;

-- Query 2/2
-- Product Text [S_PRODUCT]
-- Basic text (GRUN).
-- Internal note (IVER)
-- Not in v.1: Purchase text (BEST), Inspection text (PRUE).
-- English (en) UNION ALL Swedish (sv).
WITH cte_artnr AS (
  SELECT artnr
  FROM ar
  WHERE
    ForetagKod = 2000  -- Mall
    AND extra4 IN (11, 12)
),
cte_artnr_west AS (  -- Add v.2w.
  SELECT ar_2000.artnr
  FROM ar AS ar_2000
    LEFT OUTER JOIN ar AS ar_9100
      ON ar_2000.artnr = ar_9100.artnr
      AND ar_9100.ForetagKod = 9100  -- Väst
  WHERE
    ar_2000.ForetagKod = 2000  -- Mall
    AND ar_2000.extra4 IN (11, 12)
    AND (ar_2000.q_saps4_sortiment IN ('A', 'B')  -- A/B-sortiment: alla artiklar.
         OR (ar_2000.q_saps4_sortiment IN ('C') AND ar_9100.artnr IS NOT NULL))  -- C-sortiment: endast artiklar som finns i Väst 9100.
),
cte_artnr_north AS (  -- Add v.3n.
  SELECT ar_2000.artnr
  FROM ar AS ar_2000
    LEFT OUTER JOIN ar AS ar_9400
      ON ar_2000.artnr = ar_9400.artnr
      AND ar_9400.ForetagKod = 9400  -- Norr
  WHERE
    ar_2000.ForetagKod = 2000  -- Mall
    AND ar_2000.extra4 IN (11, 12)
    -- A/B-sortiment: inga artiklar, de har redan lång-text på global nivå.
    AND (ar_2000.q_saps4_sortiment IN ('C') AND ar_9400.artnr IS NOT NULL)  -- C-sortiment: endast artiklar som finns i Norr 9400.
)
SELECT
  ar.artnr AS AR_ArtNr,  -- Jeeves "Artikel ID"
  ar.artbeskrspec AS MARA_PRODUCT,  -- SAP Product. Jeeves "Artikelnr"
  'NORTH' AS MARA_RUN_ID  -- Change v.3n.
  'GRUN' AS PRODUCT_TDID,  -- SAP Text ID: Basic text (GRUN)
  'EN' AS PRODUCT_TDSPRAS,  -- SAP language key English
  CONCAT(TRIM(ar.artbeskr), ' ', TRIM(ar.artbeskr2)) AS PRODUCT_LONGTEXT
FROM ar
WHERE
  ar.foretagkod = 2000  -- Mall
--  AND ar.artnr IN (SELECT artnr FROM cte_artnr)  -- AR.extra4 subquery. Remove v.2w.
--  AND ar.artnr IN (SELECT artnr FROM cte_artnr_west)  -- AR.extra4 subquery. Add v.2w. Remove v.3n.
  AND ar.artnr IN (SELECT artnr FROM cte_artnr_north)  -- AR.extra4 subquery. Add v.3n.
  
UNION ALL  -- No duplicates

SELECT
  ar.artnr AS AR_ArtNr,  -- Jeeves "Artikel ID"
  ar.artbeskrspec AS MARA_PRODUCT,  -- SAP Product. Jeeves "Artikelnr"
  'NORTH' AS MARA_RUN_ID  -- Change v.3n.
  'GRUN' AS PRODUCT_TDID,  -- SAP Text ID: Basic text (GRUN)
  'SV' AS PRODUCT_TDSPRAS,  -- SAP language key Swedish
  CONCAT(TRIM(ar.artbeskr), ' ', TRIM(ar.artbeskr2)) AS PRODUCT_LONGTEXT
FROM ar
WHERE
  ar.foretagkod = 2000  -- Mall
--  AND ar.artnr IN (SELECT artnr FROM cte_artnr)  -- AR.extra4 subquery. Remove v.2w.
--  AND ar.artnr IN (SELECT artnr FROM cte_artnr_west)  -- AR.extra4 subquery. Add v.2w. Remove v.3n.
  AND ar.artnr IN (SELECT artnr FROM cte_artnr_north)  -- AR.extra4 subquery. Add v.3n.

UNION ALL  -- No duplicates

SELECT
  ar.artnr AS AR_ArtNr,  -- Jeeves "Artikel ID"
  ar.artbeskrspec AS MARA_PRODUCT,  -- SAP Product. Jeeves "Artikelnr"
  'NORTH' AS MARA_RUN_ID  -- Change v.3n.
  'IVER' AS PRODUCT_TDID,  -- SAP Text ID: Internal note (IVER)
  'SV' AS PRODUCT_TDSPRAS,  -- SAP language key Swedish
  TRIM(ar.q_interntext) AS PRODUCT_LONGTEXT  -- Jeeves Interntext, nvarchar(100) nullable
FROM ar
WHERE
  ar.foretagkod = 2000  -- Mall
--  AND ar.artnr IN (SELECT artnr FROM cte_artnr)  -- AR.extra4 subquery. Remove v.2w.
--  AND ar.artnr IN (SELECT artnr FROM cte_artnr_west)  -- AR.extra4 subquery. Add v.2w. Remove v.3n.
  AND ar.artnr IN (SELECT artnr FROM cte_artnr_north)  -- AR.extra4 subquery. Add v.3n.
  AND LEN(TRIM(COALESCE(ar.q_interntext, ''))) > 0  -- When used.

ORDER BY 2, 4, 5;

-- Query ?/?
-- MRP Text [S_MDTXT]
-- N/A v.4.

-- Query ?/?
-- Sales Text [S_MVKE]
-- N/A v.4.

-- END