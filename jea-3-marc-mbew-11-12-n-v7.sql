-- Jeeves extract article data.
-- Singelartikel, behåller artikelnummer ar.extra4 = 11

/* Change log
v.1: Inital version. Select only A-assortment plus B/C for PacsOn Väst. Add rows for reference-site/DC R310. Refer:
     dev-ecom-3-marc-mbew-11-12-v7.sql
     dev-ecom-3-marc-mbew-ref-11-12-v1.sql
     jea-99-sortiment-bc-9100-v1.sql
     Column MARC_RUN_ID use fixed value 'WEST'. Problem w date is that same article may get multiple records with different dates, then it's a mess. (Only EWM-product makes sense to have separately.)
     Availability check MARC_MTVFP is SP (was SR).
     Batch-flag MARC_XCHPF from ar.q_livsmedelgodkand.
v.2: Select #2 för Reference site/DC R310 ska bara ta artiklar som finns i Falköping (5000), så det är synk mellan SAP R310 och PVW1.
v.3: Changes per meeting 2026-05-08:
     Indicator: Autom. Purchase Oder Allowed (MARC_KAUTB): blank.
     Lot-size MARC_DISLS: EX for all, independent of anskaffningssätt (ingen fixed FX).
     Minimum lot size MARC_BSTMI: (1) AL.minantalbest, (2) ARS.eoq, (3) AL.multipel
     Maximum lot size MARC_BSTMA: n/a.
     Fixed lot size MARC_BSTFE: n/a
     Rounding value MARC_BSTRF: AL.multipel
v.4: Planned delivery time (PDT) MARC_PLIFZ is calendar days, Jeeves Ledtid is working days. Add 2 days for each weekend.
v.5: CTE cte_artnr_west: Select A/B-assortment plus C for PacsOn Väst.
v.6: Availability check MARC_MTVFP is Z2 for Jeeves-companies (was SP).
v.7: !!!PacsOn North 9400 only!!!
     !!! Fork from jea-3-marc-mbew-11-12-w-v6.sql to jea-3-marc-mbew-11-12-n-v7.sql !!!
     Add CTE cte_artnr_north
     Column MARC_RUN_ID fixed value 'NORTH' (was: WEST).
     FROM ... INNER JOIN and WHERE clauses changed.
*/

WITH cte_artnr_west AS (
  SELECT ar_2000.artnr
  FROM ar AS ar_2000
    LEFT OUTER JOIN ar AS ar_9100
      ON ar_2000.artnr = ar_9100.artnr
      AND ar_9100.ForetagKod = 9100  -- Väst
  WHERE
    ar_2000.ForetagKod = 2000  -- Mall
    AND ar_2000.extra4 IN (11, 12)
/* Remove v.5.
    AND (ar_2000.q_saps4_sortiment NOT IN ('B', 'C')  -- Ej B/C-sortiment: alla artiklar.
         OR (ar_2000.q_saps4_sortiment IN ('B', 'C') AND ar_9100.artnr IS NOT NULL))  -- B/C-sortiment: endast artiklar som finns i Väst 9100.
*/
    AND (ar_2000.q_saps4_sortiment IN ('A', 'B')  -- A/B-sortiment: alla artiklar. Change v.5.
         OR (ar_2000.q_saps4_sortiment IN ('C') AND ar_9100.artnr IS NOT NULL))  -- C-sortiment: endast artiklar som finns i Väst 9100. Change v.5.
),
cte_artnr_north AS (  -- Add v.7.
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
-- PacsOn Norr 9400, 5 lager '0', '2', '4', '5', '6'.
SELECT
  ar_2000.artnr AS AR_ArtNr,  -- Jeeves "Artikel ID"
  ar_2000.artbeskrspec AS MARC_PRODUCT,  -- SAP Product. Jeeves "Artikelnr"
  'NORTH' AS MARC_RUN_ID,  -- Change v.7.
  CONCAT(CAST(ars.ForetagKod AS nvarchar(4)), '#', ars.LagStalle) AS MARC_WERKS,  -- SAP plant

  CASE  -- Jeeves "Anskaffningssätt". ARS.LagBestPkt (decimal(15,6)).
    -- (1) Från ARS.anskaffningssatt (smallint nullable).
    WHEN ars.anskaffningssatt = 0 AND ars.LagBestPkt > 0.0 THEN 0  -- Om BP (0) och om BP-qty så BP (0)
    WHEN ars.anskaffningssatt = 0 AND NOT ars.LagBestPkt > 0.0 THEN 2  -- Om BP (0) utan BP-qty så KMB (2)
    WHEN ars.anskaffningssatt IS NOT NULL THEN ars.anskaffningssatt  -- KMB (2), etc från ARS.
    -- (2) Från AR.anskaffningssatt (smallint not nullable).
    WHEN ar_op.anskaffningssatt = 0 AND ars.LagBestPkt > 0.0 THEN 0  -- Om BP (0) och om BP-qty så BP (0).
    WHEN ar_op.anskaffningssatt = 0 AND NOT ars.LagBestPkt > 0.0 THEN 2  -- Om BP (0) utan BP-qty så KMB (2).
    ELSE ar_op.anskaffningssatt  -- KMB (2), etc från AR.
  END AS MARC_DISMM,  -- SAP MRP type

  '#001' AS MARC_DISPO,  -- SAP MRP controller
  'Z2' AS MARC_MTVFP,  -- SAP availability check. Change v.6.
  CAST(ar_op.ForetagKod AS nvarchar(4)) AS MARC_PRCTR,  -- SAP profit centre
  CASE ar_2000.q_livsmedelgodkand WHEN '1' THEN 'X' ELSE '' END AS MARC_XCHPF,  -- SAP batch management
  'Manual_0003' AS MARC_LADGR,  -- SAP loading group

-- Purchasing
  CASE ars.ForetagKod  -- (smallint not nullable)
    WHEN 6000 THEN  -- Öst
      CASE ars.LagStalle  -- (nvarchar(16))
        WHEN '20' THEN 'Åsa Björnskiöld'  -- Jordbro: Åsa.
        ELSE
          CASE WHEN ars.InkHandl = 'EB' THEN 'Erik Bergstedt' ELSE 'Tobias Wahlström' END
      END
    WHEN 9100 THEN ars.InkHandl -- Väst: Map from Jeeves inköpshandläggare.
    WHEN 9400 THEN  -- Norr, per lager.
      CASE ars.LagStalle
        WHEN '0' THEN 'Lars Fröberg'
        WHEN '2' THEN 'Eva Östlund'
        WHEN '6' THEN 'Eva Östlund'
        WHEN '4' THEN 'Lars Fröberg'
        WHEN '5' THEN 'Lars Fröberg'
      END
    WHEN 9500 THEN  -- Syd, per lager.
      CASE ars.LagStalle
        WHEN '5' THEN 'Anette Tengbom'
        WHEN '0' THEN 'Linda Gren'
        WHEN '8' THEN 'Anette Tengbom'
        WHEN '6' THEN 'Anette Tengbom'
        WHEN '7' THEN 'Anette Tengbom'
      END
  END AS MARC_EKGRP,  -- SAP purchasing group
  '' AS MARC_KAUTB,  -- SAP auto purchase order. Change v.3.
  COALESCE(ar_2000.momskod, 1) AS MARC_TAXIM,  -- SAP purchase tax. AR.momskod (smallint nullable)

-- MRP Data
  CASE
    WHEN ars.LagBestPkt > 0.0 THEN CAST(ROUND(ars.LagBestPkt, 3) AS varchar(16))  -- decimal(15,6) not nullable as varchar(16)
    ELSE CAST('' AS varchar(16))
    -- Mix decimal and '' in varchar column
  END AS MARC_MINBE,  -- SAP reorder point qty.

-- MRP Lot-Size Data
  'EX' AS MARC_DISLS,  -- SAP lot size procedure. Change v.3.
  CASE  -- (1) AL.minantalbest, (2) ARS.eoq, (3) AL.multipel. Change v.3.
    WHEN al.minantalbest > 0.0 THEN CAST(ROUND(al.minantalbest, 3) AS varchar(16))  -- decimal(15,6) not nullable as varchar(16)
    WHEN ars.eoq > 0.0 THEN CAST(ROUND(ars.eoq, 3) AS varchar(16))  -- decimal(15,6) as varchar(16)
    WHEN al.multipel > 0.0 THEN CAST(ROUND(al.multipel, 3) AS varchar(16))  -- decimal(15,6) not nullable as varchar(16)
    ELSE CAST('' AS varchar(16))
    -- Mix decimal and '' in varchar(16) column
  END AS MARC_BSTMI,  -- SAP minimum lot size. May be NULL cus AL outer join.
  CASE
    WHEN al.multipel > 0.0 THEN CAST(ROUND(al.multipel, 3) AS varchar(16))  -- decimal(15,6) not nullable as varchar(16)
    ELSE CAST('' AS varchar(16))
    -- Mix decimal and '' in varchar column
  END AS MARC_BSTRF,  -- SAP rounding value. May be NULL cus AL outer join.

-- MRP Procurement
  'Ref_MARC_DISMM' AS MARC_BESKZ,  -- SAP procurement type
  CONCAT(CAST(ars.ForetagKod AS nvarchar(4)), '#', ars.LagStalle) AS MARC_LGFSB,  -- SAP storage loc ext procurement
/* Remove v.4.
  CASE
    WHEN ars.LedTid > 0 THEN CAST(ars.LedTid AS varchar(3))  -- Jeeves Ledtid (smallint not nullable). Change v.3.
    ELSE CAST('' AS varchar(3))
  END AS MARC_PLIFZ,  -- SAP planned delivery time
*/
-- Add v.4.
-- Recalculate working days to calendar days: add 2 days for each weekend. Change v.4.
  CAST(CAST(ars.LedTid + 2 * FLOOR(ars.LedTid / 5.0) AS int) AS varchar(6))  -- Jeeves Ledtid (smallint not nullable)
    -- Integer as text, mix with '' for R310.
    AS MARC_PLIFZ,  -- SAP planned delivery time

-- Views/maintenance status
  'X' AS MARC_PSTATL,  -- Indicator: Storage
  'X' AS MARC_PSTATE,  -- Indicator: Purchasing
  'X' AS MARC_PSTATV,  -- Indicator: Sales

-- Värderingsdata / Valuation Data [S_MBEW]
  2 AS MBEW_MLAST,  -- SAP Price Control Determination = Transaction-based.
  3100 AS MBEW_BKLAS,  -- SAP Valuation Class.
  'V' AS MBEW_VPRSV,  -- SAP Price Control = moving average.
  'SEK' AS MBEW_WAERS,  -- SAP Currency

  ROUND(CASE
    WHEN ars.ArtKalkBer > 0.0 THEN ars.ArtKalkBer        -- (1) ARS (artikel & lager): "Kalkylpris Bas" ArtKalkBer per "Kalkylprisenhet" 10^ArtKalkPer
    WHEN ar_op.ArtKalkBer > 0.0 THEN ar_op.ArtKalkBer    -- (2) AR (artikel): "Kalkylpris Bas" ArtKalkBer per "Kalkylprisenhet" 10^ArtKalkPer
    WHEN ar_op.ArtKalkPris > 0.0 THEN ar_op.ArtKalkPris  -- (3) AR (artikel): "Beräknat kalkylpris" ArtKalkPris per "Kalkylprisenhet" 10^ArtKalkPer
    ELSE 0.01                                            -- (4) Dummy-värde: 0,01 SEK per 1 basenhet.
  END, 2) AS MBEW_VERPR,  -- SAP Inventory Price Moving Average
  CAST(ROUND(POWER(10.0, CASE
    WHEN ars.ArtKalkBer > 0.0 THEN ars.ArtKalkPer        -- (1)
    WHEN ar_op.ArtKalkBer > 0.0 OR ar_op.ArtKalkPris > 0.0 THEN ar_op.ArtKalkPer  -- (2) & (3)
    ELSE 0                                               -- (4) 10^0 = 1
  END), 0) AS int) AS MBEW_PEINH,  -- SAP Price Unit (quantity)

  'X' AS MBEW_PSTATB  -- Indicator: Accounting

FROM
  ar AS ar_2000  -- Mall
  INNER JOIN ar AS ar_op  -- Operativa bolag
    ON ar_2000.artnr = ar_op.artnr
    AND ar_2000.ForetagKod = 2000  -- Mall
--  AND ar_op.ForetagKod IN (6000, 9100, 9400, 9500)  -- ÖVNS. Remove v.1.
--  AND ar_op.ForetagKod IN (9100)  -- Väst. Add v.1. Remove v.7.
    AND ar_op.ForetagKod IN (9400)  -- Norr. Add v.7.
  INNER JOIN ars
    ON ars.foretagkod = ar_op.foretagkod
    AND ars.artnr = ar_op.artnr
  LEFT OUTER JOIN al
    ON al.foretagkod = ar_op.foretagkod
    AND al.artnr = ar_op.artnr
    AND al.ArtHuvudAvt = '1'  -- Jeeves: endast huvudavtal (char(1))
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
/* Remove v.7.
  (ars.ForetagKod = 9100 AND ars.LagStalle IN ('5000') )  -- Väst. Add v.1.
  AND ar_2000.artnr IN (SELECT artnr FROM cte_artnr_west)  -- AR.extra4 subquery. Change v.1
*/
  (ars.ForetagKod = 9400 AND ars.LagStalle IN ('0', '2', '4', '5', '6') )  -- Norr. Add v.7.
  AND ar_2000.artnr IN (SELECT artnr FROM cte_artnr_north)  -- AR.extra4 subquery. Add v.7.

UNION ALL  -- No duplicates

-- Reference site/DC R310.
SELECT
  ar_2000.artnr AS AR_ArtNr,  -- Jeeves "Artikel ID"
  ar_2000.artbeskrspec AS MARC_PRODUCT,  -- SAP Product. Jeeves "Artikelnr"
  'NORTH' AS MARC_RUN_ID,  -- Change v.7.
  CONCAT(CAST(ar_2000.ForetagKod AS nvarchar(4)), '#', 'REF') AS MARC_WERKS,  -- SAP plant

  2 AS MARC_DISMM,  -- SAP MRP type. Default: Köp mot behov (2) => PD.
  '#001' AS MARC_DISPO,  -- SAP MRP controller
  'Z2' AS MARC_MTVFP,  -- SAP availability check. Change v.6.
  CAST('' AS nvarchar(4)) AS MARC_PRCTR,  -- SAP profit centre
  CASE ar_2000.q_livsmedelgodkand WHEN '1' THEN 'X' ELSE '' END AS MARC_XCHPF,  -- SAP batch management
  'Manual_0003' AS MARC_LADGR,  -- SAP loading group

-- Purchasing
  '' AS MARC_EKGRP,  -- SAP purchasing group
  '' AS MARC_KAUTB,  -- SAP auto purchase order. Change v.3.
  COALESCE(ar_2000.momskod, 1) AS MARC_TAXIM,  -- SAP purchase tax. AR.momskod (smallint nullable)

-- MRP Data
  CAST('' AS varchar(16)) AS MARC_MINBE,  -- SAP reorder point qty.

-- MRP Lot-Size Data
  'EX' AS MARC_DISLS,  -- SAP lot size procedure
  CAST('' AS varchar(16)) AS MARC_BSTMI,  -- SAP minimum lot size
  CAST('' AS varchar(16)) AS MARC_BSTRF,  -- SAP rounding value

-- MRP Procurement
  'Ref_MARC_DISMM' AS MARC_BESKZ,  -- SAP procurement type
  '' AS MARC_LGFSB,  -- SAP storage loc ext procurement
  CAST('' AS varchar(6)) AS MARC_PLIFZ,  -- SAP planned delivery time

-- Views/maintenance status
  'X' AS MARC_PSTATL,  -- Indicator: Storage
  'X' AS MARC_PSTATE,  -- Indicator: Purchasing
  'X' AS MARC_PSTATV,  -- Indicator: Sales

-- Värderingsdata / Valuation Data [S_MBEW]
  2 AS MBEW_MLAST,  -- SAP Price Control Determination = Transaction-based.
  3100 AS MBEW_BKLAS,  -- SAP Valuation Class.
  'V' AS MBEW_VPRSV,  -- SAP Price Control = moving average.
  'SEK' AS MBEW_WAERS,  -- SAP Currency

  0.01 AS MBEW_VERPR,  -- SAP Inventory Price Moving Average. (4) Dummy-värde: 0,01 SEK per 1 basenhet.
  CAST(ROUND(POWER(10.0, 0), 0) AS int) AS MBEW_PEINH,  -- SAP Price Unit (quantity). (4) 10^0 = 1

  'X' AS MBEW_PSTATB  -- Indicator: Accounting

FROM
  ar AS ar_2000  -- Mall
  INNER JOIN ar AS ar_op  -- Operativa bolag
    ON ar_2000.artnr = ar_op.artnr
    AND ar_2000.ForetagKod = 2000  -- Mall
--  AND ar_op.ForetagKod IN (6000, 9100, 9400, 9500)  -- ÖVNS. Remove v.1.
    AND ar_op.ForetagKod IN (9100)  -- Väst. Add v.1.
  INNER JOIN ars
    ON ars.foretagkod = ar_op.foretagkod
    AND ars.artnr = ar_op.artnr
  LEFT OUTER JOIN al
    ON al.foretagkod = ar_op.foretagkod
    AND al.artnr = ar_op.artnr
    AND al.ArtHuvudAvt = '1'  -- Jeeves: endast huvudavtal (char(1))
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
/* Remove v.7.
  (ars.ForetagKod = 9100 AND ars.LagStalle IN ('5000') )  -- Väst. Add v.1.
  AND ar_2000.artnr IN (SELECT artnr FROM cte_artnr_west)  -- AR.extra4 subquery. Change v.1
*/
  (ars.ForetagKod = 9400 AND ars.LagStalle IN ('0', '2', '4', '5', '6') )  -- Norr. Add v.7.
  AND ar_2000.artnr IN (SELECT artnr FROM cte_artnr_north)  -- AR.extra4 subquery. Add v.7.

ORDER BY 2, 3, 4;

-- END