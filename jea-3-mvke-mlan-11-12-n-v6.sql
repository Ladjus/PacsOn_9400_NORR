-- Jeeves extract article data.
-- Singelartikel, behåller artikelnummer ar.extra4 = 11

/* Change log
v.1: Inital version. Select only A-assortment plus B/C for PacsOn Väst. Refer:
     dev-ecom-3-mvke-mlan-11-12-v6.sql
     jea-99-sortiment-bc-9100-v1.sql
     Column MVKE_RUN_ID use fixed value 'WEST'. Problem w date is that same article may get multiple records with different dates, then it's a mess.
     Column MVKE_VMSTA from ar.q_saps4_sortiment
     Column MVKE_VMSTD per ar.q_saps4_sortiment
v.2: Inkludera endast artiklar som finns i Falköping (5000).
v.3: CTE cte_artnr_west: Select A/B-assortment plus C for PacsOn Väst.
v.4: Inkludera artiklar i Väst även om de inte finns i Falköping (5000), undo v.2. Remove INNER JOIN ars and WHERE-condition.
v.5: Add distribution channel 50 via UNION ALL SELECT.
     Column MVKE_VMSTA change to handle ar.q_saps4_sortiment = '' etc.
     Column MVKE_VMSTD change to varchar(10), to allow ''.
     Column MVKE_SCMNG added.
     Column MVKE_SCHME added.
v.6: !!!PacsOn North 9400 only!!!
     !!! Fork from jea-3-mvke-mlan-11-12-w-v5.sql to jea-3-mvke-mlan-11-12-n-v6.sql !!!
     Add CTE cte_artnr_north
     Column MVKE_RUN_ID and MLAN_RUN_ID fixed value 'NORTH' (was: WEST).
     FROM ... INNER JOIN and WHERE clauses changed, three SELECTs.
*/

-- Sales data (load structure S_MVKE)
WITH cte_artnr_west AS (
  SELECT ar_2000.artnr
  FROM ar AS ar_2000
    LEFT OUTER JOIN ar AS ar_9100
      ON ar_2000.artnr = ar_9100.artnr
      AND ar_9100.ForetagKod = 9100  -- Väst
  WHERE
    ar_2000.ForetagKod = 2000  -- Mall
    AND ar_2000.extra4 IN (11, 12)
/* Remove v.3.
    AND (ar_2000.q_saps4_sortiment NOT IN ('B', 'C')  -- Ej B/C-sortiment: alla artiklar.
         OR (ar_2000.q_saps4_sortiment IN ('B', 'C') AND ar_9100.artnr IS NOT NULL))  -- B/C-sortiment: endast artiklar som finns i Väst 9100.
*/
    AND (ar_2000.q_saps4_sortiment IN ('A', 'B')  -- A/B-sortiment: alla artiklar. Change v.3.
         OR (ar_2000.q_saps4_sortiment IN ('C') AND ar_9100.artnr IS NOT NULL))  -- C-sortiment: endast artiklar som finns i Väst 9100. Change v.3.
),
cte_artnr_north AS (  -- Add v.6.
  SELECT ar_2000.artnr
  FROM ar AS ar_2000
    LEFT OUTER JOIN ar AS ar_9400
      ON ar_2000.artnr = ar_9400.artnr
      AND ar_9400.ForetagKod = 9400  -- Norr
  WHERE
    ar_2000.ForetagKod = 2000  -- Mall
    AND ar_2000.extra4 IN (11, 12)
    AND (ar_2000.q_saps4_sortiment IN ('A', 'B')  -- A/B-sortiment: alla artiklar.
         OR (ar_2000.q_saps4_sortiment IN ('C') AND ar_9400.artnr IS NOT NULL))  -- C-sortiment: endast artiklar som finns i Norr 9400.
)
-- Distribution channel 10
SELECT
  ar_2000.artnr AS AR_ArtNr,  -- Jeeves "Artikel ID"
  ar_2000.artbeskrspec AS MVKE_PRODUCT,  -- SAP Product. Jeeves "Artikelnr"
  'NORTH' AS MVKE_RUN_ID,  -- Change v.6.
  ar_op.ForetagKod AS MVKE_VKORG,  -- SAP sales org
  10 AS MVKE_VTWEG,  -- SAP distribution channel

-- Sales status
--  COALESCE(ar_2000.q_saps4_sortiment, '') AS MVKE_VMSTA,  -- SAP sales status per assortment. Change v.1. Remove v.5.
  CASE  -- Add v.5.
    WHEN ar_2000.q_saps4_sortiment IN ('A', 'B', 'C')  -- A/B/C
      THEN ar_2000.q_saps4_sortiment
    ELSE ''  -- NULL or '' or junk
  END AS MVKE_VMSTA,  -- SAP sales status, per assortment
--  CASE WHEN ar_2000.q_saps4_sortiment IS NOT NULL THEN CAST(GETDATE() AS date) ELSE CAST(NULL AS date) END  -- Remove v.5.
  CASE  -- Add v.5.
    WHEN ar_2000.q_saps4_sortiment IN ('A', 'B', 'C')  -- A/B/C
      THEN CAST(CAST(GETDATE() AS date) AS varchar(10))
    ELSE CAST('' AS varchar(10))  -- NULL or '' or junk
  END AS MVKE_VMSTD,  -- SAP sales status date, if assortment

-- Quantity Stipulations
  CASE ar_op.anskaffningssatt
    WHEN 0 THEN  -- Beställningspunkt (0) ==> tag Förpackningsstorlek försäljning ar_op.artfsgforp decimal(15,6).
      CASE
        WHEN ar_op.artfsgforp > 0.0 AND FLOOR(ar_op.artfsgforp) = CEILING(ar_op.artfsgforp)  -- Integer value > 0.
          THEN CAST(CAST(ar_op.artfsgforp AS int) AS varchar(16))  -- integer as varchar(16).
        WHEN ar_op.artfsgforp > 0.0  -- Decimal value > 0.
          THEN CAST(ROUND(ar_op.artfsgforp, 3) AS varchar(16))  -- decimal(15,6) as varchar(16).
        ELSE CAST('' AS varchar(16))  -- Nil.
        -- Mix integer, decimal and '' in varchar column
      END
    WHEN 2 THEN  -- Köp mot behov (2) ==> tag Förpackningsstorlek förs ansk ar_op.q_artfsgforp decimal(14,3).
      CASE
        WHEN ar_op.q_artfsgforp > 0.0 AND FLOOR(ar_op.q_artfsgforp) = CEILING(ar_op.q_artfsgforp)  -- Integer value > 0.
          THEN CAST(CAST(ar_op.q_artfsgforp AS int) AS varchar(16))  -- integer as varchar(16).
        WHEN ar_op.q_artfsgforp > 0.0  -- Decimal value > 0.
          THEN CAST(ROUND(ar_op.q_artfsgforp, 3) AS varchar(16))  -- decimal(14,3) as varchar(16).
        ELSE CAST('' AS varchar(16))  -- Nil.
        -- Mix integer, decimal and '' in varchar column
      END
    ELSE CAST('' AS varchar(16))
  END AS MVKE_AUMNG,  -- SAP Minimum Order Quantity in Base UoM

  CASE ar_op.anskaffningssatt
    WHEN 0 THEN  -- Beställningspunkt (0) ==> tag Förpackningsstorlek försäljning ar_op.artfsgforp decimal(15,6).
      CASE
        WHEN ar_op.artfsgforp > 0.0 AND FLOOR(ar_op.artfsgforp) = CEILING(ar_op.artfsgforp)  -- Integer value > 0.
          THEN CAST(CAST(ar_op.artfsgforp AS int) AS varchar(16))  -- integer as varchar(16).
        WHEN ar_op.artfsgforp > 0.0  -- Decimal value > 0.
          THEN CAST(ROUND(ar_op.artfsgforp, 3) AS varchar(16))  -- decimal(15,6) as varchar(16).
        ELSE CAST('' AS varchar(16))  -- Nil.
        -- Mix integer, decimal and '' in varchar column
      END
    WHEN 2 THEN  -- Köp mot behov (2) ==> tag Förpackningsstorlek förs ansk ar_op.q_artfsgforp decimal(14,3).
      CASE
        WHEN ar_op.q_artfsgforp > 0.0 AND FLOOR(ar_op.q_artfsgforp) = CEILING(ar_op.q_artfsgforp)  -- Integer value > 0.
          THEN CAST(CAST(ar_op.q_artfsgforp AS int) AS varchar(16))  -- integer as varchar(16).
        WHEN ar_op.q_artfsgforp > 0.0  -- Decimal value > 0.
          THEN CAST(ROUND(ar_op.q_artfsgforp, 3) AS varchar(16))  -- decimal(14,3) as varchar(16).
        ELSE CAST('' AS varchar(16))  -- Nil.
        -- Mix integer, decimal and '' in varchar column
      END
    ELSE CAST('' AS varchar(16))
  END AS MVKE_SCMNG,  -- SAP Delivery Unit (quantity)
  '' AS MVKE_SCHME,  -- SAP Delivery Unit UoM

-- Grouping Terms
  CASE
    WHEN ar_op.ordtyp = 10 THEN 'CBNA'  -- "3rd party SO w/o SN".
    ELSE  -- ar_op.ordtyp <> 10
      CASE ar_op.anskaffningssatt  -- (smallint not nullable)
        WHEN 0 THEN 'NORM'  -- BP. "Standard item".
        WHEN 2 THEN 'CBUK'  -- KMB. "Bought-in".
        ELSE 'NORM'  -- Default: "Standard item".
      END
  END AS MVKE_MTPOS,  -- SAP Item Category Group
  'Z1' AS MVKE_KTGRM  -- SAP Account Assignment Group
FROM  -- Refer MARC-query but without AL-table.
  ar AS ar_2000  -- Mall
  INNER JOIN ar AS ar_op  -- Operativa bolag
    ON ar_2000.artnr = ar_op.artnr
    AND ar_2000.ForetagKod = 2000  -- Mall
--  AND ar_op.ForetagKod IN (6000, 9100, 9400, 9500)  -- ÖVNS. Remove v.1.
--  AND ar_op.ForetagKod IN (9100)  -- Väst. Add v.1. Remove v.6.
    AND ar_op.ForetagKod IN (9400)  -- Norr. Add v.6.
/* Remove v.4.
  INNER JOIN ars
    ON ars.foretagkod = ar_op.foretagkod
    AND ars.artnr = ar_op.artnr
*/
WHERE
  -- Specifika lager: ARS.ForetagKod (smallint) och ARS.LagStalle (nvarchar(16))
  -- Ref: "PacsOn Org structure_Final_2.xlsx" URL https://optigroup.sharepoint.com/sites/ASAP-Projektplats/Shared%20Documents/ASAP-%20Projektplats/Arkitektur%20&%20Teknisk%20upps%C3%A4ttning/Org.%20struktur/Pacson%20Org%20structure_Final_2.xlsx
/* Remove v.1.
  (  (ars.ForetagKod = 6000 AND ars.LagStalle IN ('20', '30', '101', '102') )  -- Öst
  OR (ars.ForetagKod = 9100 AND ars.LagStalle IN ('5000') )  -- Väst
  OR (ars.ForetagKod = 9400 AND ars.LagStalle IN ('0', '2', '4', '5', '6') )  -- Norr
  OR (ars.ForetagKod = 9500 AND ars.LagStalle IN ('0', '5', '6', '7', '8') )  -- Syd
  )
*/
--  (ars.ForetagKod = 9100 AND ars.LagStalle IN ('5000') )  -- Väst. Add v.1. Remove v.4.
--  AND  -- Remove v.4.
--  ar_2000.artnr IN (SELECT artnr FROM cte_artnr_west)  -- AR.extra4 subquery. Change v.1. Remove v.6.
  ar_2000.artnr IN (SELECT artnr FROM cte_artnr_north)  -- AR.extra4 subquery. Add v.6.

UNION ALL  -- No duplicates

-- Distribution channel 50
SELECT
  ar_2000.artnr AS AR_ArtNr,  -- Jeeves "Artikel ID"
  ar_2000.artbeskrspec AS MVKE_PRODUCT,  -- SAP Product. Jeeves "Artikelnr"
  'NORTH' AS MVKE_RUN_ID,  -- Change v.6.
  ar_op.ForetagKod AS MVKE_VKORG,  -- SAP sales org
  50 AS MVKE_VTWEG,  -- SAP distribution channel

-- Sales status
  '' AS MVKE_VMSTA,  -- SAP sales status
  CAST('' AS varchar(10)) AS MVKE_VMSTD,  -- SAP sales status date

-- Quantity Stipulations
  CAST('' AS varchar(16)) AS MVKE_AUMNG,  -- SAP Minimum Order Quantity in Base UoM
  CAST('' AS varchar(16)) AS MVKE_SCMNG,  -- SAP Delivery Unit (quantity)
  '' AS MVKE_SCHME,  -- SAP Delivery Unit UoM

-- Grouping Terms
  'NORM' AS MVKE_MTPOS,  -- SAP Item Category Group
  'Z1' AS MVKE_KTGRM  -- SAP Account Assignment Group
FROM  -- Refer MARC-query but without AL-table.
  ar AS ar_2000  -- Mall
  INNER JOIN ar AS ar_op  -- Operativa bolag
    ON ar_2000.artnr = ar_op.artnr
    AND ar_2000.ForetagKod = 2000  -- Mall
--  AND ar_op.ForetagKod IN (6000, 9100, 9400, 9500)  -- ÖVNS. Remove v.1.
--  AND ar_op.ForetagKod IN (9100)  -- Väst. Add v.1. Remove v.6.
    AND ar_op.ForetagKod IN (9400)  -- Norr. Add v.6.
/* Remove v.4.
  INNER JOIN ars
    ON ars.foretagkod = ar_op.foretagkod
    AND ars.artnr = ar_op.artnr
*/
WHERE
  -- Specifika lager: ARS.ForetagKod (smallint) och ARS.LagStalle (nvarchar(16))
  -- Ref: "PacsOn Org structure_Final_2.xlsx" URL https://optigroup.sharepoint.com/sites/ASAP-Projektplats/Shared%20Documents/ASAP-%20Projektplats/Arkitektur%20&%20Teknisk%20upps%C3%A4ttning/Org.%20struktur/Pacson%20Org%20structure_Final_2.xlsx
/* Remove v.1.
  (  (ars.ForetagKod = 6000 AND ars.LagStalle IN ('20', '30', '101', '102') )  -- Öst
  OR (ars.ForetagKod = 9100 AND ars.LagStalle IN ('5000') )  -- Väst
  OR (ars.ForetagKod = 9400 AND ars.LagStalle IN ('0', '2', '4', '5', '6') )  -- Norr
  OR (ars.ForetagKod = 9500 AND ars.LagStalle IN ('0', '5', '6', '7', '8') )  -- Syd
  )
*/
--  (ars.ForetagKod = 9100 AND ars.LagStalle IN ('5000') )  -- Väst. Add v.1. Remove v.4.
--  AND  -- Remove v.4.
--  ar_2000.artnr IN (SELECT artnr FROM cte_artnr_west)  -- AR.extra4 subquery. Change v.1. Remove v.6.
  ar_2000.artnr IN (SELECT artnr FROM cte_artnr_north)  -- AR.extra4 subquery. Add v.6.
ORDER BY 2, 3, 4, 5;

-- Sales tax classification (load structure S_MLAN). One (1) country for all locations, select from mallbolaget 2000.
-- (If consistency problems, SELECT DISTINCT from operational companies, but then risk of duplicates if inconsistent AR.momskod.)
WITH cte_artnr_west AS (
  SELECT ar_2000.artnr
  FROM ar AS ar_2000
    LEFT OUTER JOIN ar AS ar_9100
      ON ar_2000.artnr = ar_9100.artnr
      AND ar_9100.ForetagKod = 9100  -- Väst
  WHERE
    ar_2000.ForetagKod = 2000  -- Mall
    AND ar_2000.extra4 IN (11, 12)
/* Remove v.3.
    AND (ar_2000.q_saps4_sortiment NOT IN ('B', 'C')  -- Ej B/C-sortiment: alla artiklar.
         OR (ar_2000.q_saps4_sortiment IN ('B', 'C') AND ar_9100.artnr IS NOT NULL))  -- B/C-sortiment: endast artiklar som finns i Väst 9100.
*/
    AND (ar_2000.q_saps4_sortiment IN ('A', 'B')  -- A/B-sortiment: alla artiklar. Change v.3.
         OR (ar_2000.q_saps4_sortiment IN ('C') AND ar_9100.artnr IS NOT NULL))  -- C-sortiment: endast artiklar som finns i Väst 9100. Change v.3.
),
cte_artnr_north AS (  -- Add v.6.
  SELECT ar_2000.artnr
  FROM ar AS ar_2000
    LEFT OUTER JOIN ar AS ar_9400
      ON ar_2000.artnr = ar_9400.artnr
      AND ar_9400.ForetagKod = 9400  -- Norr
  WHERE
    ar_2000.ForetagKod = 2000  -- Mall
    AND ar_2000.extra4 IN (11, 12)
    AND (ar_2000.q_saps4_sortiment IN ('A', 'B')  -- A/B-sortiment: alla artiklar.
         OR (ar_2000.q_saps4_sortiment IN ('C') AND ar_9400.artnr IS NOT NULL))  -- C-sortiment: endast artiklar som finns i Norr 9400.
)
SELECT
  ar_2000.artnr AS AR_ArtNr,  -- Jeeves "Artikel ID". Change v.2 _2000
  ar_2000.artbeskrspec AS MLAN_PRODUCT,  -- SAP Product. Change v.2 _2000
  'NORTH' AS MLAN_RUN_ID,  -- Change v.6.
  'SE' AS MLAN_ALAND,
  'TTX1' AS MLAN_TATYP1,
  COALESCE(ar_2000.momskod, 1) AS MLAN_TAXM1  -- SAP sales tax. AR.momskod (smallint nullable). Change v.2 _2000
FROM  -- Refer MARC-query but without AL-table.
  ar AS ar_2000  -- Mall
  INNER JOIN ar AS ar_op  -- Operativa bolag
    ON ar_2000.artnr = ar_op.artnr
    AND ar_2000.ForetagKod = 2000  -- Mall
--  AND ar_op.ForetagKod IN (6000, 9100, 9400, 9500)  -- ÖVNS. Remove v.1.
--  AND ar_op.ForetagKod IN (9100)  -- Väst. Add v.1. Remove v.6.
  AND ar_op.ForetagKod IN (9400)  -- Norr. Add v.6.
/* Remove v.4.
  INNER JOIN ars
    ON ars.foretagkod = ar_op.foretagkod
    AND ars.artnr = ar_op.artnr
*/
WHERE
  -- Specifika lager: ARS.ForetagKod (smallint) och ARS.LagStalle (nvarchar(16))
  -- Ref: "PacsOn Org structure_Final_2.xlsx" URL https://optigroup.sharepoint.com/sites/ASAP-Projektplats/Shared%20Documents/ASAP-%20Projektplats/Arkitektur%20&%20Teknisk%20upps%C3%A4ttning/Org.%20struktur/Pacson%20Org%20structure_Final_2.xlsx
/* Remove v.1.
  (  (ars.ForetagKod = 6000 AND ars.LagStalle IN ('20', '30', '101', '102') )  -- Öst
  OR (ars.ForetagKod = 9100 AND ars.LagStalle IN ('5000') )  -- Väst
  OR (ars.ForetagKod = 9400 AND ars.LagStalle IN ('0', '2', '4', '5', '6') )  -- Norr
  OR (ars.ForetagKod = 9500 AND ars.LagStalle IN ('0', '5', '6', '7', '8') )  -- Syd
  )
*/
--  (ars.ForetagKod = 9100 AND ars.LagStalle IN ('5000') )  -- Väst. Add v.1. Remove v.4.
--  AND  -- Remove v.4.
--  ar_2000.artnr IN (SELECT artnr FROM cte_artnr_west)  -- AR.extra4 subquery. Change v.1. Remove v.6.
  ar_2000.artnr IN (SELECT artnr FROM cte_artnr_north)  -- AR.extra4 subquery. Add v.6.
ORDER BY 2, 3;

-- END