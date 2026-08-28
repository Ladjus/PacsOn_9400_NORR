-- Jeeves extract article data.
-- Singelartikel, behåller artikelnummer ar.extra4 = 11

/* Change log
v.1: Initial version. Merge 3 query for global data MARA (basic data), MARM (alt-units), MEAN (2nd-GTIN) in one SQL-file since the Jeeves data for this is in one (1) table, so extract must be taken at once to enconsistent and taken at once. Refer:
     dev-ecom-2-mara-makt-11-12-v4.sql
     dev-ecom-2-marm-11-12-v7.sql
     dev-ecom-2-mean-11-12-v2.sql
     dev-ecom-EAN-test-v3.sql
     Column MARA_XCHPF from ar.q_livsmedelgodkand.
     Column MARA_MSTAV from ar.q_saps4_sortiment.
     Column MARA_MSTDV run-time date.
v.2: 2nd query gives MARM duplicate rows for same unit with 2 different GTIN/EAN codes.
     Bugg-fix in LEFT OUTER JOIN cte_ean_au_rn ON ...
     Add column INFO_RN with ROW_NUMBER() value.
     Column MARA_EAN11 with COALESCE(..., '') to avoid NULL result.
     Column MARM_EAN11 with COALESCE(..., '') to avoid NULL result.
v.3: Column MARA_MSTAV with COALESCE(ar.q_saps4_sortiment, '') to avoid NULL result.
     MARA_MSTDV only if ar.q_saps4_sortiment not NULL.
     MARM_UMREZ: xare.AltEnhetOmrFaktor must not be NULL, exclude some junk data.
v.4w: !!!PacsOn Väst 9100 only!!!
     Add CTE cte_artnr_west
v.5w: Column MARA_MSTDE with date.
v.6w: Exclude alternative units: fpall, vol, sl, lave, halvpall, enh; in WHERE-clause. (Was: exclude fpall, vol.)
v.7n: !!!PacsOn North 9400 only!!!
     !!! Fork from jea-2-mara-makt-mean-11-12-v6w.sql to jea-2-mara-makt-mean-11-12-v7n.sql !!!
     Add CTE cte_artnr_north
     WHERE clauses changed.
*/

-- Query 1/3
-- Grunddata (obligatoriskt) / Basic Data (mandatory) [S_MARA]
-- Ytterligare beskrivningar / Additional Descriptions [S_MAKT]
WITH cte_artnr AS (
  SELECT artnr
  FROM ar
  WHERE
    ForetagKod = 2000  -- Mall
    AND extra4 IN (11, 12)
),
cte_artnr_west AS (  -- Add v.4w.
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
cte_artnr_north AS (  -- Add v.7n.
  SELECT ar_2000.artnr
  FROM ar AS ar_2000
    LEFT OUTER JOIN ar AS ar_9400
      ON ar_2000.artnr = ar_9400.artnr
      AND ar_9400.ForetagKod = 9400  -- Norr
  WHERE
    ar_2000.ForetagKod = 2000  -- Mall
    AND ar_2000.extra4 IN (11, 12)
    -- A/B-sortiment: inga artiklar, de är redan laddade på global nivå.
    AND (ar_2000.q_saps4_sortiment IN ('C') AND ar_9400.artnr IS NOT NULL)  -- C-sortiment: endast artiklar som finns i Norr 9400.
),
cte_ean_bu AS (  -- EAN for base units (not alt-units).
  SELECT
    ar.artnr AS AR_ArtNr,  -- Jeeves "Artikel ID"
    COALESCE(arean.AltEnhetKod, ar.EnhetsKod, 'ERROR') AS MEAN_MEINH,  -- SAP unit. Jeeves AltEnhetKod nullable (basenhet); EnhetsKod not nullable.
    CAST(TRIM(arean.ArtNrEAN) AS varchar(18)) AS MEAN_EAN11  -- SAP GTIN char(18). Jeeves nvarchar(60) not nullable.
  FROM ar
    INNER JOIN arean
      ON ar.foretagkod = arean.foretagkod
      AND ar.artnr = arean.artnr
      AND arean.AltEnhetKod IS NULL  -- Basenhet
  WHERE
    ar.foretagkod = 2000  -- Mall
    AND ar.artnr IN (SELECT artnr FROM cte_artnr)  -- AR.extra4 subquery.
    AND LEN(TRIM(arean.ArtNrEAN)) BETWEEN 13 AND 14  -- Only GTIN-13 & GTIN-14, rest is junk.
),
cte_ean_bu_rn AS (  -- ROW_NUMBER() AS RN
  SELECT
    *,
    ROW_NUMBER() OVER (
      PARTITION BY AR_ArtNr, MEAN_MEINH
      ORDER BY MEAN_EAN11
    ) AS RN
  FROM cte_ean_bu
)
SELECT
  ar.artnr AS AR_ArtNr,  -- Jeeves "Artikel ID"
  ar.artbeskrspec AS MARA_PRODUCT,  -- SAP Product. Jeeves "Artikelnr"
  'HAWA' AS MARA_MTART,  -- SAP Product type
  'Single_00' AS MARA_ATTYP,  -- Article category 00 single article
  CONCAT(ar.artkod, '#', ar.artkat) AS MARA_MATKL,
  LEFT(CONCAT(TRIM(ar.artbeskr), ' ', TRIM(ar.artbeskr2)), 40) AS MARA_MAKTX,  -- Artikelbeskrivning 40 tecken
  'EN' AS MARA_SPRAS,
  ar.enhetskod AS MARA_MEINS,
--  cte_ean_bu_rn.MEAN_EAN11 AS MARA_EAN11,  -- SAP GTIN, 1:a för basenhet. (AR.ArtNrEAN är död.) Remove v.2.
  COALESCE(cte_ean_bu_rn.MEAN_EAN11, '') AS MARA_EAN11,  -- SAP GTIN, 1:a för basenhet. (AR.ArtNrEAN är död.) Add v.2.
  cte_ean_bu_rn.RN AS INFO_RN,
  'Std_00' AS MARA_SPART,  -- SAP Division
  CASE
    WHEN LEN(TRIM(COALESCE(ar.q_artnr_pacudo, ''))) > 0 THEN TRIM(ar.q_artnr_pacudo)
    ELSE ar.artbeskrspec
  END AS MARA_BISMT,  -- SAP Old mtrl: (1) Pacudo, (2) Jeeves
  CASE ar.q_livsmedelgodkand WHEN '1' THEN 'X' ELSE '' END AS MARA_XCHPF,  -- SAP Batch Management Required
  COALESCE(ar.q_unspsckod, '') AS MARA_EXTWG,  -- SAP External product group
  'NORM' AS MARA_MTPOS_MARA,
  ar.itemstatuscode AS MARA_MSTAE,  -- Cross-Plant Product Status. Jeeves "Artikelstatus" smallint not nullable
  CAST(CAST(GETDATE() AS date) AS varchar(10)) AS MARA_MSTDE,  -- Valid-From Date. Change v.5w.
  CAST(
    CASE
      WHEN ar.artbtotvikt > 0.0 THEN ROUND(ar.artbtotvikt, 3)  -- decimal(15,4) not nullable
      WHEN ar.artvikt > 0.0 THEN ROUND(ar.artvikt, 3)  -- decimal(15,4) not nullable
      ELSE 0.000
    END AS decimal(14,3))
    AS MARA_BRGEW,  -- SAP BU gross weight, decimal(15,4) as decimal(14,3). Change v.4.
  CAST(CASE WHEN ar.artvikt > 0.0 THEN ROUND(ar.artvikt, 3) ELSE 0.000 END AS decimal(14,3))
    AS MARA_NTGEW,  -- SAP BU net weight, decimal(15,4) as decimal(14,3). Change v.4.
  'KG' AS MARA_GEWEI,  -- SAP weight unit
  ROUND(ar.artvolym, 3) AS MARA_VOLUM,  -- Jeeves "Volym kbm" (float)
  'M3' AS MARA_VOLEH,  -- SAP volume unit
  'Std_0001' AS MARA_TRAGR,  -- SAP Transportation Group
--  ar.q_saps4_sortiment AS MARA_MSTAV,  -- SAP Cross-Distribution Chain Product Status. Remove v.3.
  COALESCE(ar.q_saps4_sortiment ,'') AS MARA_MSTAV,  -- SAP Cross-Distribution Chain Product Status. Add v.3.
--  CAST(GETDATE() AS date) AS MARA_MSTDV,  -- SAP Valid From Date for Status. Remove v.3.
  CASE WHEN ar.q_saps4_sortiment IS NOT NULL THEN CAST(GETDATE() AS date) ELSE CAST(NULL AS date) END
    AS MARA_MSTDV,  -- SAP Valid From Date for Status. Add v.3.
  '3100' AS MARA_WBKLA,  -- Reference value: Valuation Class
  COALESCE(ar.momskod, 1) AS MARA_TAKLV,  -- Reference value: Tax Classification. Jeeves "Momskod" smallint nullable
  'Manual_0003' AS MARA_WLADG,  -- Reference value: Loading Group
  'SV' AS MAKT_SPRAS,
  LEFT(CONCAT(TRIM(AR.artbeskr), ' ', TRIM(AR.artbeskr2)), 40) AS MAKT_MAKTX  -- Artikelbeskrivning 40 tecken
FROM ar
  LEFT OUTER JOIN cte_ean_bu_rn
    ON ar.artnr = cte_ean_bu_rn.AR_ArtNr
    AND cte_ean_bu_rn.RN = 1  -- Primär GTIN för basenhet
WHERE
  ar.foretagkod = 2000  -- Mall
--  AND ar.artnr IN (SELECT artnr FROM cte_artnr_west)  -- AR.extra4 subquery. Remove v.7n.
  AND ar.artnr IN (SELECT artnr FROM cte_artnr_north)  -- AR.extra4 subquery. Add v.7n.
ORDER BY 2;

-- Query 2/3
-- Alternativa mängdenheter / Alternative Units of Measure [S_MARM]
WITH cte_artnr AS (
  SELECT artnr
  FROM ar
  WHERE
    ForetagKod = 2000  -- Mall
    AND extra4 IN (11, 12)
),
cte_artnr_west AS (  -- Add v.4w.
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
cte_artnr_north AS (  -- Add v.7n.
  SELECT ar_2000.artnr
  FROM ar AS ar_2000
    LEFT OUTER JOIN ar AS ar_9400
      ON ar_2000.artnr = ar_9400.artnr
      AND ar_9400.ForetagKod = 9400  -- Norr
  WHERE
    ar_2000.ForetagKod = 2000  -- Mall
    AND ar_2000.extra4 IN (11, 12)
    -- A/B-sortiment: inga artiklar, de är redan laddade på global nivå.
    AND (ar_2000.q_saps4_sortiment IN ('C') AND ar_9400.artnr IS NOT NULL)  -- C-sortiment: endast artiklar som finns i Norr 9400.
),
cte_ean_au AS (  -- EAN for alt-units (not base unit).
  SELECT
    ar.artnr AS AR_ArtNr,  -- Jeeves "Artikel ID"
    COALESCE(arean.AltEnhetKod, ar.EnhetsKod, 'ERROR') AS MEAN_MEINH,  -- SAP unit. Jeeves AltEnhetKod nullable (basenhet); EnhetsKod not nullable.
    CAST(TRIM(arean.ArtNrEAN) AS varchar(18)) AS MEAN_EAN11  -- SAP GTIN char(18). Jeeves nvarchar(60) not nullable.
  FROM ar
    INNER JOIN arean
      ON ar.foretagkod = arean.foretagkod
     AND ar.artnr = arean.artnr
     AND arean.AltEnhetKod <> ar.EnhetsKod  -- Alternativ enhet
  WHERE
    ar.foretagkod = 2000  -- Mall
    AND ar.artnr IN (SELECT artnr FROM cte_artnr)  -- AR.extra4 subquery.
    AND LEN(TRIM(arean.ArtNrEAN)) BETWEEN 13 AND 14  -- Only GTIN-13 & GTIN-14, rest is junk.
),
cte_ean_au_rn AS (  -- ROW_NUMBER() AS RN
  SELECT
    *,
    ROW_NUMBER() OVER (
      PARTITION BY AR_ArtNr, MEAN_MEINH
      ORDER BY MEAN_EAN11
    ) AS RN
  FROM cte_ean_au
)
SELECT
  ar.artnr AS AR_ArtNr,  -- Jeeves "Artikel ID"
  ar.enhetskod AS AR_EnhetsKod,  -- Jeeves basenhet
  ar.artbeskrspec AS MARM_PRODUCT,  -- SAP Product. Jeeves "Artikelnr"
  xare.AltEnhetKod AS MARM_MEINH,  -- Alternative Unit of Measure
  1 AS MARM_UMREN,  -- Denominator for Conversion to Base Unit
  CASE
    WHEN FLOOR(xare.AltEnhetOmrFaktor) = CEILING(xare.AltEnhetOmrFaktor)  -- If integer value
      THEN CAST(CAST(xare.AltEnhetOmrFaktor AS int) AS varchar(13))  -- integer as varchar(13)
    ELSE CAST(xare.AltEnhetOmrFaktor AS varchar(13))  -- decimal(12,6) as varchar(13)
    -- Mix integer and decimal in varchar column.
  END AS MARM_UMREZ,  -- Numerator for Conversion to Base Unit
  CASE
    WHEN xare.AltEnhetOmrFaktor >= 100000.0 THEN 'OVERFLOW'  -- SAP maximum 5 digits!
    WHEN NOT(FLOOR(xare.AltEnhetOmrFaktor) = CEILING(xare.AltEnhetOmrFaktor)) THEN 'DECIMAL'  -- SAP fractions must be with UMREN <> 1!
    ELSE ''
  END AS SAP_ERROR,  -- Problem i SAP S/4!
--  cte_ean_au_rn.MEAN_EAN11 AS MARM_EAN11,  -- SAP GTIN, 1:a för alt-enhet. Remove v.2.
  COALESCE(cte_ean_au_rn.MEAN_EAN11, '') AS MARM_EAN11,  -- SAP GTIN, 1:a för alt-enhet. Add v.2.
  cte_ean_au_rn.RN AS INFO_RN,
  CAST(ROUND(xare.AltEnhetOmrFaktor *  -- decimal(12,6) nullable
    CASE
      WHEN ar.artbtotvikt > 0.0 THEN ar.artbtotvikt  -- decimal(15,4) not nullable
      WHEN ar.artvikt > 0.0 THEN ar.artvikt  -- decimal(15,4) not nullable
      ELSE 0.0
    END, 3) AS decimal(14,3))
    AS MARM_BRGEW,  -- SAP alt-unit gross weight, as decimal(14,3)
  'KG' AS MARM_GEWEI,  -- SAP weight unit
  'M3' AS MARM_VOLEH  -- SAP volume unit
FROM
  ar
  INNER JOIN xare
    ON ar.foretagkod = xare.foretagkod
    AND ar.artnr = xare.artnr
  LEFT OUTER JOIN cte_ean_au_rn
    ON ar.artnr = cte_ean_au_rn.AR_ArtNr
    AND xare.AltEnhetKod = cte_ean_au_rn.MEAN_MEINH  -- Bugg-fix v.2.
    AND cte_ean_au_rn.RN = 1  -- Primär GTIN för alternativ enhet
WHERE
  ar.foretagkod = 2000  -- Mall
--  AND ar.artnr IN (SELECT artnr FROM cte_artnr_west)  -- AR.extra4 subquery. Remove v.7n.
  AND ar.artnr IN (SELECT artnr FROM cte_artnr_north)  -- AR.extra4 subquery. Add v.7n.
  AND xare.AltEnhetKod <> ar.enhetskod  -- Exclude base-unit of measure.
  AND LOWER(xare.AltEnhetKod) NOT IN ('fpall', 'vol', 'sl', 'lave', 'halvpall', 'enh')  -- Exclude fraktpall, etc. Add v.6w.
  AND xare.AltEnhetOmrFaktor IS NOT NULL  -- Exclude junk rows. Add v.3.
ORDER BY 3, 4;

-- Query 3/3
-- Ytterligare GTIN / Additional GTINs [S_MEAN]
WITH cte_artnr AS (
  SELECT artnr
  FROM ar
  WHERE
    ForetagKod = 2000  -- Mall
    AND extra4 IN (11, 12)
),
cte_artnr_west AS (  -- Add v.4w.
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
cte_artnr_north AS (  -- Add v.7n.
  SELECT ar_2000.artnr
  FROM ar AS ar_2000
    LEFT OUTER JOIN ar AS ar_9400
      ON ar_2000.artnr = ar_9400.artnr
      AND ar_9400.ForetagKod = 9400  -- Norr
  WHERE
    ar_2000.ForetagKod = 2000  -- Mall
    AND ar_2000.extra4 IN (11, 12)
    -- A/B-sortiment: inga artiklar, de är redan laddade på global nivå.
    AND (ar_2000.q_saps4_sortiment IN ('C') AND ar_9400.artnr IS NOT NULL)  -- C-sortiment: endast artiklar som finns i Norr 9400.
),
cte_ean AS (  -- EAN for all units.
  SELECT
    ar.artnr AS AR_ArtNr,  -- Jeeves "Artikel ID"
    COALESCE(arean.AltEnhetKod, ar.EnhetsKod, 'ERROR') AS MEAN_MEINH,  -- SAP unit. Jeeves AltEnhetKod nullable (basenhet); EnhetsKod not nullable.
    CAST(TRIM(arean.ArtNrEAN) AS varchar(18)) AS MEAN_EAN11  -- SAP GTIN char(18). Jeeves nvarchar(60) not nullable.
  FROM ar
    INNER JOIN arean
      ON ar.foretagkod = arean.foretagkod
     AND ar.artnr = arean.artnr
  WHERE
    ar.foretagkod = 2000  -- Mall
    AND ar.artnr IN (SELECT artnr FROM cte_artnr)  -- AR.extra4 subquery.
    AND LEN(TRIM(arean.ArtNrEAN)) BETWEEN 13 AND 14  -- Only GTIN-13 & GTIN-14, rest is junk.
),
cte_ean_rn AS (  -- ROW_NUMBER() AS RN
  SELECT
    *,
    ROW_NUMBER() OVER (
      PARTITION BY AR_ArtNr, MEAN_MEINH
      ORDER BY MEAN_EAN11
    ) AS RN
  FROM cte_ean
)
SELECT
  ar.artnr AS AR_ArtNr,  -- Jeeves "Artikel ID"
  ar.artbeskrspec AS MEAN_PRODUCT,  -- SAP Product. Jeeves "Artikelnr"
  cte_ean_rn.MEAN_MEINH,  -- SAP unit
  cte_ean_rn.MEAN_EAN11,  -- SAP GTIN, 2:a för basenhet och alt-enhet.
  cte_ean_rn.RN AS INFO_RN
FROM ar
  INNER JOIN cte_ean_rn
    ON ar.artnr = cte_ean_rn.AR_ArtNr
    AND cte_ean_rn.RN > 1  -- Sekundär GTIN för bas- och alternativ enhet
WHERE
  ar.foretagkod = 2000  -- Mall
--  AND ar.artnr IN (SELECT artnr FROM cte_artnr_west)  -- AR.extra4 subquery. Remove v.7n.
  AND ar.artnr IN (SELECT artnr FROM cte_artnr_north)  -- AR.extra4 subquery. Add v.7n.
ORDER BY 2, 3, 4;

-- END