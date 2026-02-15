-- ============================================================
-- Vue 360° Missions — Agrégation par mission (11 CTE)
-- ============================================================
-- Grain : 1 ligne = 1 mission (ID_MISSION)
-- Rôle  : vue synthèse pour la DAF — budget, trajets, transports,
--         indemnités, repas, nuits, remboursements, avances,
--         indicateur de cohérence financière
--
-- CORRECTION MAJEURE : agrégation sur ID_MISSION (clé technique)
-- et non NUMERO_MISSION (réutilisable entre exercices)
-- ============================================================

CREATE OR REPLACE VIEW VUE_MISSIONS_CUMUL AS
WITH

-- ============================================================
-- CTE 1 : Budget — agrégation des lignes budgétaires
-- ============================================================
Budget_Agg AS (
    SELECT
        b.ID_MISSION,
        COUNT(b.ID_BUDGET)          AS NB_LIGNES_BUDGET,
        COUNT(DISTINCT b.ID_EB)     AS NB_ENTITES_BUDGETAIRES,
        SUM(b.MONTANT_BUDGETAIRE)   AS BUDGET_MONTANT_TOTAL,
        SUM(b.MONTANT_REMBOURSE)    AS BUDGET_MONTANT_REMBOURSE,
        SUM(b.MONTANT_BUDGETAIRE
          - b.MONTANT_REMBOURSE)    AS BUDGET_RESTE_A_REMBOURSER,
        -- Listes agrégées (ON OVERFLOW TRUNCATE = sécurité VARCHAR2)
        LISTAGG(DISTINCT b.ID_EB, ', '
            ON OVERFLOW TRUNCATE WITH COUNT)
            WITHIN GROUP (ORDER BY b.ID_EB)
            AS LISTE_EB,
        LISTAGG(DISTINCT b.ID_NATURE_DEPENSE, ', '
            ON OVERFLOW TRUNCATE WITH COUNT)
            WITHIN GROUP (ORDER BY b.ID_NATURE_DEPENSE)
            AS LISTE_NATURES
    FROM MIS_BUDGET b
    WHERE b.TEM_VALIDE = 'O'
    GROUP BY b.ID_MISSION
),

-- ============================================================
-- CTE 2 : Trajets — géographie, durée, pays, zones
-- ============================================================
Trajets_Agg AS (
    SELECT
        t.ID_MISSION,
        COUNT(t.ID_TRAJET)                      AS NB_TRAJETS,
        SUM(t.DATE_FIN - t.DATE_DEBUT)           AS DUREE_TOTALE_JOURS,
        MIN(t.DATE_DEBUT)                        AS PREMIER_DEPART,
        MAX(t.DATE_FIN)                          AS DERNIERE_ARRIVEE,
        LISTAGG(DISTINCT p.LIBELLE, ' | '
            ON OVERFLOW TRUNCATE)
            WITHIN GROUP (ORDER BY p.LIBELLE)    AS PAYS_LISTE,
        COUNT(DISTINCT p.ID_PAYS)                AS NB_PAYS,
        -- Drapeaux étranger / DOM-TOM
        MAX(CASE WHEN z.TEM_ETRANGER = 'O'
            THEN 'OUI' ELSE 'NON' END)          AS AVEC_ETRANGER,
        MAX(CASE WHEN z.TEM_DOM_TOM = 'O'
            THEN 'OUI' ELSE 'NON' END)          AS AVEC_DOM_TOM
    FROM MIS_TRAJET t
    LEFT JOIN MIS_PAYS p    ON t.ID_PAYS = p.ID_PAYS
    LEFT JOIN MIS_REMB_ZONE z ON t.ID_REMB_ZONE = z.ID_REMB_ZONE
    WHERE t.TEM_VALIDE = 'O'
    GROUP BY t.ID_MISSION
),

-- ============================================================
-- CTE 3 : Transports — montants, kms, perso vs service
-- ============================================================
Transports_Agg AS (
    SELECT
        t.ID_MISSION,
        COUNT(tt.ID_TRAJET_TRANSPORT)            AS NB_TRANSPORTS,
        SUM(tt.MONTANT)                          AS MONTANT_TOTAL,
        SUM(tt.KMS)                              AS KMS_TOTAL,
        -- Ventilation conditionnelle perso / service
        COUNT(CASE WHEN typ.TEM_PERSONNEL = 'O'
              THEN tt.ID_TRAJET_TRANSPORT END)   AS NB_PERSO,
        SUM(CASE WHEN typ.TEM_PERSONNEL = 'O'
            THEN tt.MONTANT ELSE 0 END)          AS MONTANT_PERSO,
        SUM(CASE WHEN typ.TEM_PERSONNEL = 'O'
            THEN tt.KMS ELSE 0 END)              AS KMS_PERSO,
        COUNT(CASE WHEN typ.TEM_PERSONNEL = 'N'
              THEN tt.ID_TRAJET_TRANSPORT END)   AS NB_SERVICE,
        SUM(CASE WHEN typ.TEM_PERSONNEL = 'N'
            THEN tt.MONTANT ELSE 0 END)          AS MONTANT_SERVICE
    FROM MIS_TRAJET_TRANSPORTS tt
    INNER JOIN MIS_TRAJET t ON tt.ID_TRAJET = t.ID_TRAJET
    LEFT JOIN MIS_TYPE_TRANSPORT typ
        ON tt.ID_TYPE_TRANSPORT = typ.ID_TYPE_TRANSPORT
    WHERE tt.TEM_VALIDE = 'O' AND t.TEM_VALIDE = 'O'
    GROUP BY t.ID_MISSION
),

-- ============================================================
-- CTE 4-7 : Indemnités étranger, Repas, Nuits, Remboursements
-- (même pattern : jointure trajet → agrégation par mission)
-- ============================================================

-- [...CTE Indemnites, Repas, Nuits, Remboursements...]
-- (voir documentation complète pour le détail)

-- ============================================================
-- CTE 8 : Avances — montants, validées, liquidées
-- ============================================================
Avances_Agg AS (
    SELECT
        a.ID_MISSION,
        COUNT(a.ID_AVANCE)                       AS NB_AVANCES,
        SUM(a.MONTANT)                           AS MONTANT_TOTAL,
        -- Ventilation par statut
        COUNT(CASE WHEN a.TEM_VALIDE = 'O'
              THEN a.ID_AVANCE END)              AS NB_VALIDEES,
        SUM(CASE WHEN a.TEM_VALIDE = 'O'
            THEN a.MONTANT ELSE 0 END)           AS MONTANT_VALIDE,
        COUNT(CASE WHEN a.TEM_LIQUIDATION = 'O'
              THEN a.ID_AVANCE END)              AS NB_LIQUIDEES,
        SUM(CASE WHEN a.TEM_LIQUIDATION = 'O'
            THEN a.MONTANT ELSE 0 END)           AS MONTANT_LIQUIDE,
        MIN(a.DATE_PAIEMENT)                     AS PREMIERE_DATE,
        MAX(a.DATE_PAIEMENT)                     AS DERNIERE_DATE
    FROM MIS_AVANCES a
    GROUP BY a.ID_MISSION
)

-- ============================================================
-- SELECT PRINCIPAL
-- ============================================================
SELECT
    m.ID_MISSION,
    m.NUMERO            AS NUMERO_MISSION,      -- restitution métier
    m.ID_EXERCICE       AS EXERCICE,            -- restitution métier

    -- Dates + dérivés temporels
    m.DATE_DEBUT        AS MISSION_DATE_DEBUT,
    m.DATE_FIN          AS MISSION_DATE_FIN,
    m.DATE_FIN - m.DATE_DEBUT AS MISSION_DUREE_JOURS,
    TO_CHAR(m.DATE_DEBUT, 'YYYY')  AS ANNEE,
    TO_CHAR(m.DATE_DEBUT, 'Q')     AS TRIMESTRE,

    -- Montants globaux
    m.MONTANT_TOTAL     AS MISSION_MONTANT_PREVU,
    m.MONTANT_PAIEMENT  AS MISSION_MONTANT_A_PAYER,

    -- Blocs agrégés (COALESCE = jamais de NULL → simplifie Excel)
    COALESCE(b.BUDGET_MONTANT_TOTAL, 0)   AS BUDGET_MONTANT_TOTAL,
    COALESCE(tr.NB_TRAJETS, 0)            AS TRAJETS_NB,
    COALESCE(trans.MONTANT_TOTAL, 0)      AS TRANSPORTS_MONTANT,
    COALESCE(trans.KMS_TOTAL, 0)          AS TRANSPORTS_KMS,
    -- ... (tous les blocs CTE)

    -- ========================================================
    -- INDICATEUR DE COHERENCE FINANCIERE
    -- ========================================================
    (
        COALESCE(trans.MONTANT_TOTAL, 0)
      + COALESCE(ind.MONTANT_TOTAL, 0)       -- indemnités étranger
      + COALESCE(rep.MONTANT_TOTAL, 0)       -- repas France
      + COALESCE(nui.MONTANT_TOTAL, 0)       -- nuits France
      + COALESCE(remb.MONTANT_TOTAL, 0)      -- remboursements
    ) AS TOTAL_FRAIS_CALCULE,

    CASE
        WHEN ABS(m.MONTANT_TOTAL - (
            COALESCE(trans.MONTANT_TOTAL, 0)
          + COALESCE(ind.MONTANT_TOTAL, 0)
          + COALESCE(rep.MONTANT_TOTAL, 0)
          + COALESCE(nui.MONTANT_TOTAL, 0)
          + COALESCE(remb.MONTANT_TOTAL, 0)
        )) < 0.01 THEN 'COHERENT'
        WHEN ABS(m.MONTANT_TOTAL - (
            COALESCE(trans.MONTANT_TOTAL, 0)
          + COALESCE(ind.MONTANT_TOTAL, 0)
          + COALESCE(rep.MONTANT_TOTAL, 0)
          + COALESCE(nui.MONTANT_TOTAL, 0)
          + COALESCE(remb.MONTANT_TOTAL, 0)
        )) < 10 THEN 'ECART_MINEUR'
        ELSE 'ECART_IMPORTANT'
    END AS STATUT_COHERENCE

FROM MIS_MISSION m

-- Référentiels
INNER JOIN MIS_ETAT e            ON m.ID_ETAT = e.ID_ETAT
INNER JOIN MIS_TITRE_MISSION tm  ON m.ID_TITRE_MISSION = tm.ID_TITRE_MISSION
LEFT  JOIN MIS_PAYEUR p          ON m.ID_PAYEUR = p.ID_PAYEUR

-- 11 CTE agrégées
LEFT JOIN Budget_Agg b           ON m.ID_MISSION = b.ID_MISSION
LEFT JOIN Trajets_Agg tr         ON m.ID_MISSION = tr.ID_MISSION
LEFT JOIN Transports_Agg trans   ON m.ID_MISSION = trans.ID_MISSION
-- LEFT JOIN Indemnites_Etranger_Agg ind ON ...
-- LEFT JOIN Repas_Agg rep ON ...
-- LEFT JOIN Nuits_Agg nui ON ...
-- LEFT JOIN Remboursements_Agg remb ON ...
LEFT JOIN Avances_Agg av         ON m.ID_MISSION = av.ID_MISSION
-- LEFT JOIN Depenses_Agg dep ON ...
-- LEFT JOIN Commandes_Agg cmd ON ...
-- LEFT JOIN Reimputations_Agg reim ON ...

WHERE m.TEM_VALIDE = 'O';
