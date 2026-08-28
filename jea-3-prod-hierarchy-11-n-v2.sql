-- Jeeves extract article data.
-- Singelartikel, behåller artikelnummer ar.extra4 = 11

/* Change log
v.1: Initial. Select only A-assortment plus B/C for PacsOn Väst. Refer:
     dev-ecom-9-prod-hierarchy-v1.sql
     Add CTE cte_artnr_west.
     Add exclusion list for 43 CONCAT(AR.artkod, '#', AR.artkat)-combinations.
v.2: !!!PacsOn North 9400 only!!!
     !!! Fork from jea-3-prod-hierarchy-11-w-v1.sql to jea-3-prod-hierarchy-11-n-v2.sql !!!
     Add CTE cte_artnr_north
     WHERE clauses changed.
*/

-- (1) "Product hierarchy version" tab, structure S_ASSIGNMENT
WITH cte_artnr_west AS (  -- Add v.1.
  SELECT ar_2000.artnr
  FROM ar AS ar_2000
    LEFT OUTER JOIN ar AS ar_9100
      ON ar_2000.artnr = ar_9100.artnr
      AND ar_9100.ForetagKod = 9100  -- Väst
  WHERE
    ar_2000.ForetagKod = 2000  -- Mall
    AND ar_2000.extra4 IN (11)
    AND (ar_2000.q_saps4_sortiment IN ('A', 'B')  -- A/B-sortiment: alla artiklar.
         OR (ar_2000.q_saps4_sortiment IN ('C') AND ar_9100.artnr IS NOT NULL))  -- C-sortiment: endast artiklar som finns i Väst 9100.
),
cte_artnr_north AS (  -- Add v.2.
  SELECT ar_2000.artnr
  FROM ar AS ar_2000
    LEFT OUTER JOIN ar AS ar_9400
      ON ar_2000.artnr = ar_9400.artnr
      AND ar_9400.ForetagKod = 9400  -- Norr
  WHERE
    ar_2000.ForetagKod = 2000  -- Mall
    AND ar_2000.extra4 IN (11, 12)
    -- A/B-sortiment: inga artiklar, de är redan PH-assignade.
    AND (ar_2000.q_saps4_sortiment IN ('C') AND ar_9400.artnr IS NOT NULL)  -- C-sortiment: endast artiklar som finns i Norr 9400.
)
SELECT
  ar.artnr AS AR_ArtNr,  -- Jeeves "Artikel ID"
  'ART01' AS ASSIGNMENT_HIER_ID,  -- Hierarchy ID
  '9999-12-31' AS ASSIGNMENT_VER_VLDTO,  -- Valid to
  ar.artbeskrspec AS ASSIGNMENT_RUN_ID  -- Run ID, separate per article. Jeeves "Artikelnr"
FROM ar
WHERE
  ar.foretagkod = 2000  -- Mall
--  AND ar.artnr IN (SELECT artnr FROM cte_artnr_west)  -- AR.extra4 subquery. Remove v.2.
  AND ar.artnr IN (SELECT artnr FROM cte_artnr_north)  -- AR.extra4 subquery. Add v.2.
  AND CONCAT(ar.artkod, '#', ar.artkat)  -- Exclude articles which do not have a hierarchy node mapping, to avoid assignment to ART01_ZZ99.
    NOT IN (  -- Exclude 43 combinations.
      '10#101',
      '10#102',
      '10#117',
      '10#172',
      '10#999',
      '11#115',
      '11#172',
      '11#709',
      '12#117',
      '12#182',
      '12#709',
      '12#999',
      '13#152',
      '13#199',
      '14#165',
      '15#152',
      '15#171',
      '15#172',
      '15#207',
      '15#999',
      '16#172',
      '16#199',
      '30#143',
      '30#178',
      '30#202',
      '30#205',
      '30#302',
      '30#303',
      '40#507',
      '40#509',
      '50#129',
      '50#174',
      '60#174',
      '60#601',
      '60#602',
      '60#609',
      '60#999',
      '70#309',
      '70#709',
      '70#999',
      '99#',
      '99#182',
      '99#999')
ORDER BY 4;  -- ASSIGNMENT_RUN_ID

-- (2) "Product assignment" tab, structure S_ASSIGN_PRODUCT
WITH cte_artnr_west AS (  -- Add v.1.
  SELECT ar_2000.artnr
  FROM ar AS ar_2000
    LEFT OUTER JOIN ar AS ar_9100
      ON ar_2000.artnr = ar_9100.artnr
      AND ar_9100.ForetagKod = 9100  -- Väst
  WHERE
    ar_2000.ForetagKod = 2000  -- Mall
    AND ar_2000.extra4 IN (11)
    AND (ar_2000.q_saps4_sortiment IN ('A', 'B')  -- A/B-sortiment: alla artiklar.
         OR (ar_2000.q_saps4_sortiment IN ('C') AND ar_9100.artnr IS NOT NULL))  -- C-sortiment: endast artiklar som finns i Väst 9100.
),
cte_artnr_north AS (  -- Add v.2.
  SELECT ar_2000.artnr
  FROM ar AS ar_2000
    LEFT OUTER JOIN ar AS ar_9400
      ON ar_2000.artnr = ar_9400.artnr
      AND ar_9400.ForetagKod = 9400  -- Norr
  WHERE
    ar_2000.ForetagKod = 2000  -- Mall
    AND ar_2000.extra4 IN (11, 12)
    -- A/B-sortiment: inga artiklar, de är redan PH-assignade.
    AND (ar_2000.q_saps4_sortiment IN ('C') AND ar_9400.artnr IS NOT NULL)  -- C-sortiment: endast artiklar som finns i Norr 9400.
)
SELECT
  ar.artnr AS AR_ArtNr,  -- Jeeves "Artikel ID"
  'ART01' AS ASSIGN_PROD_HIER_ID,  -- Hierarchy ID
  '9999-12-31' AS ASSIGN_PROD_VER_VLDTO,  -- Valid to
  ar.artbeskrspec AS ASSIGN_PROD_RUN_ID,  -- Run ID, separate per article. Jeeves "Artikelnr"
  ar.artbeskrspec AS ASSIGN_PROD_NODE_VALUE,  -- SAP Product. What about cross-reference???
  CONCAT(ar.artkod, '#', ar.artkat) AS ASSIGN_PROD_PARENT_NODE_VALUE  -- SAP Subnode. Jeeves Artikelklass # Artikelkategori.
FROM ar
WHERE
  ar.foretagkod = 2000  -- Mall
--  AND ar.artnr IN (SELECT artnr FROM cte_artnr_west)  -- AR.extra4 subquery. Remove v.2.
  AND ar.artnr IN (SELECT artnr FROM cte_artnr_north)  -- AR.extra4 subquery. Add v.2.
  AND CONCAT(ar.artkod, '#', ar.artkat)  -- Exclude articles which do not have a hierarchy node mapping, to avoid assignment to ART01_ZZ99.
    NOT IN (  -- Exclude 43 combinations.
      '10#101',
      '10#102',
      '10#117',
      '10#172',
      '10#999',
      '11#115',
      '11#172',
      '11#709',
      '12#117',
      '12#182',
      '12#709',
      '12#999',
      '13#152',
      '13#199',
      '14#165',
      '15#152',
      '15#171',
      '15#172',
      '15#207',
      '15#999',
      '16#172',
      '16#199',
      '30#143',
      '30#178',
      '30#202',
      '30#205',
      '30#302',
      '30#303',
      '40#507',
      '40#509',
      '50#129',
      '50#174',
      '60#174',
      '60#601',
      '60#602',
      '60#609',
      '60#999',
      '70#309',
      '70#709',
      '70#999',
      '99#',
      '99#182',
      '99#999')
ORDER BY 4;  -- ASSIGN_PROD_RUN_ID

-- END