-- ============================================================
-- Vue agents permanents QVT (9 CTE)
-- ============================================================
-- Grain  : 1 ligne = 1 agent
-- Rôle   : liste des agents (actifs et sortis) pour la gestion
--          des droits d'accès QVT
-- Sortie : 10 colonnes (identité, affectation, dates, email)
--
-- CORRECTION v1.1 : bug DATE_SORTIE
-- MAX(D_FIN_CONTRAT_AV) ignorait les NULL (prolongation)
-- → remplacé par sélection de l'avenant le plus récent
-- ============================================================

CREATE OR REPLACE VIEW V_AGENTS_QVT AS
WITH

-- ============================================================
-- CTE 1 : Identité + dédoublonnage
-- ROW_NUMBER pour éliminer les doublons (jamais DISTINCT)
-- ============================================================
lda AS (
    SELECT * FROM (
        SELECT
            L.NO_INDIVIDU, L.CIV, L.NOM, L.PRENOM,
            L.NOM_PATR, L.AFFECTATION, L.CORPS,
            -- Normalisation des accents pour comparaisons
            UPPER(TRANSLATE(
                L.POSITION,
                'ÀÂÄÉÈÊËÎÏÔÖÙÛÜYàâäéèêëîïôöùûüÿÇç',
                'AAAEEEEIIOOUUUYAAAEEEEIIOOUUUYCc'
            )) AS POSITION_NORM,
            ROW_NUMBER() OVER (
                PARTITION BY L.NO_INDIVIDU
                ORDER BY L.AFFECTATION, L.NOM
            ) AS rn
        FROM LISTE_DONNEES_AGENTS L
    )
    WHERE rn = 1
),

-- ============================================================
-- CTE 2 : Email unique et sécurisé (1 par agent)
-- Ajout automatique du domaine si absent
-- ============================================================
mail AS (
    SELECT
        i.NO_INDIVIDU,
        CASE
            WHEN ce.EMAIL IS NULL OR TRIM(ce.EMAIL) = '' THEN NULL
            WHEN INSTR(ce.EMAIL, '@') = 0
                THEN LOWER(ce.EMAIL) || '@domaine.fr'
            ELSE LOWER(ce.EMAIL)
        END AS EMAIL,
        ROW_NUMBER() OVER (
            PARTITION BY i.NO_INDIVIDU
            ORDER BY LOWER(ce.EMAIL)
        ) AS rn
    FROM INDIVIDU i
    JOIN COMPTE c     ON c.PERS_ID = i.PERS_ID
    JOIN COMPTE_EMAIL ce ON ce.CPT_ORDRE = c.CPT_ORDRE
),

-- ============================================================
-- CTE 3 : Fin effective par contrat (correction v1.1)
--
-- AVANT (buggé) : MAX(D_FIN_CONTRAT_AV)
--   → ignorait les NULL = prolongation indéfinie
--
-- APRÈS : on prend la D_FIN de l'avenant le plus récent
--   → gère correctement les prolongations
-- ============================================================
contrat_av_fin AS (
    SELECT NO_SEQ_CONTRAT, D_FIN_CONTRAT_AV
    FROM (
        SELECT
            ca.NO_SEQ_CONTRAT,
            ca.D_FIN_CONTRAT_AV,
            ROW_NUMBER() OVER (
                PARTITION BY ca.NO_SEQ_CONTRAT
                ORDER BY ca.D_DEB_CONTRAT_AV DESC,
                         ca.CTRA_ORDRE DESC
            ) AS rn
        FROM CONTRAT_AVENANT ca
        WHERE ca.TEM_ANNULATION = 'N'
    )
    WHERE rn = 1
),

-- ============================================================
-- CTE 4 : Contrat principal
-- Priorité au contrat actif aujourd'hui, sinon le plus récent
-- D_FIN_EFF = fin anticipée si avenant, sinon fin du contrat
-- ============================================================
cc AS (
    SELECT NO_DOSSIER_PERS, D_DEB_CONTRAT, D_FIN_EFF, IS_ACTIF
    FROM (
        SELECT
            ct.NO_DOSSIER_PERS,
            ct.D_DEB_CONTRAT_TRAV AS D_DEB_CONTRAT,
            COALESCE(ca.D_FIN_CONTRAT_AV,
                     ct.D_FIN_CONTRAT_TRAV) AS D_FIN_EFF,
            CASE
                WHEN ct.D_DEB_CONTRAT_TRAV <= TRUNC(SYSDATE)
                 AND (COALESCE(ca.D_FIN_CONTRAT_AV,
                               ct.D_FIN_CONTRAT_TRAV) IS NULL
                      OR COALESCE(ca.D_FIN_CONTRAT_AV,
                                  ct.D_FIN_CONTRAT_TRAV) >= TRUNC(SYSDATE))
                THEN 1 ELSE 0
            END AS IS_ACTIF,
            ROW_NUMBER() OVER (
                PARTITION BY ct.NO_DOSSIER_PERS
                ORDER BY
                    -- Contrat actif en priorité
                    CASE WHEN /* contrat actif */ 1=1 THEN 0 ELSE 1 END,
                    ct.D_DEB_CONTRAT_TRAV DESC
            ) AS rn
        FROM CONTRAT ct
        LEFT JOIN contrat_av_fin ca
            ON ca.NO_SEQ_CONTRAT = ct.NO_SEQ_CONTRAT
        WHERE ct.TEM_ANNULATION = 'N'
    )
    WHERE rn = 1
),

-- CTE 5 : Première position (ancrage date d'entrée)
fp AS (
    SELECT NO_DOSSIER_PERS, MIN(D_DEB_POSITION) AS FIRST_POS
    FROM CHANGEMENT_POSITION
    WHERE TEM_VALIDE = 'O'
    GROUP BY NO_DOSSIER_PERS
),

-- CTE 6 : Dernière fin de position (pour agents sans position active)
lp AS (
    SELECT NO_DOSSIER_PERS, MAX(D_FIN_POSITION) AS LAST_FIN_POS
    FROM (
        SELECT cp.*,
            MAX(CASE
                WHEN D_DEB_POSITION <= TRUNC(SYSDATE)
                 AND (D_FIN_POSITION IS NULL
                      OR D_FIN_POSITION >= TRUNC(SYSDATE))
                THEN 1 ELSE 0
            END) OVER (PARTITION BY NO_DOSSIER_PERS) AS HAS_ACTIVE
        FROM CHANGEMENT_POSITION cp
        WHERE TEM_VALIDE = 'O'
    )
    WHERE HAS_ACTIVE = 0 AND D_FIN_POSITION IS NOT NULL
    GROUP BY NO_DOSSIER_PERS
),

-- CTE 7 : Positions actives aujourd'hui
ap AS (
    SELECT NO_DOSSIER_PERS, 1 AS HAS_POS_ACTIVE
    FROM CHANGEMENT_POSITION
    WHERE TEM_VALIDE = 'O'
      AND D_DEB_POSITION <= TRUNC(SYSDATE)
      AND (D_FIN_POSITION IS NULL
           OR D_FIN_POSITION >= TRUNC(SYSDATE))
    GROUP BY NO_DOSSIER_PERS
),

-- CTE 8 : Hébergés actifs (exclusion QVT)
heberges_actifs AS (
    SELECT DISTINCT NO_DOSSIER_PERS
    FROM CONTRAT_HEBERGES
    WHERE TEM_VALIDE = 'O'
      AND D_DEB <= TRUNC(SYSDATE)
      AND (D_FIN IS NULL OR D_FIN >= TRUNC(SYSDATE))
),

-- ============================================================
-- CTE 9 : Base consolidée — calcul dates d'entrée / sortie
-- ============================================================
base AS (
    SELECT
        lda.*,
        -- Date d'entrée : priorité variable selon position active
        CASE
            WHEN ap.HAS_POS_ACTIVE = 1
                THEN COALESCE(fp.FIRST_POS, cc.D_DEB_CONTRAT)
            ELSE
                COALESCE(cc.D_DEB_CONTRAT, fp.FIRST_POS)
        END AS D_ENTREE,

        -- Date de sortie : NULL si actif, sinon fin contrat/position
        CASE
            WHEN ap.HAS_POS_ACTIVE = 1 THEN NULL
            ELSE COALESCE(cc.D_FIN_EFF, lp.LAST_FIN_POS)
        END AS D_SORTIE

    FROM lda
    LEFT JOIN cc ON cc.NO_DOSSIER_PERS = lda.NO_INDIVIDU
    LEFT JOIN fp ON fp.NO_DOSSIER_PERS = lda.NO_INDIVIDU
    LEFT JOIN lp ON lp.NO_DOSSIER_PERS = lda.NO_INDIVIDU
    LEFT JOIN ap ON ap.NO_DOSSIER_PERS = lda.NO_INDIVIDU
)

-- ============================================================
-- SELECT FINAL : 1 ligne/agent, exclusion hébergés
-- ============================================================
SELECT
    TO_CHAR(SYSDATE, 'DD/MM/YYYY HH24:MI') AS GENTIME,
    b.CIV, b.NOM, b.PRENOM, b.NOM_PATR,
    b.AFFECTATION, b.CORPS,
    TO_CHAR(b.D_ENTREE, 'DD/MM/YYYY')      AS DATE_ENTREE,
    NVL(TO_CHAR(b.D_SORTIE, 'DD/MM/YYYY'), '') AS DATE_SORTIE,
    NVL(m.EMAIL, '')                         AS EMAIL
FROM base b
LEFT JOIN mail m
    ON m.NO_INDIVIDU = b.NO_INDIVIDU AND m.rn = 1
WHERE b.D_ENTREE IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM heberges_actifs h
      WHERE h.NO_DOSSIER_PERS = b.NO_INDIVIDU
  )
ORDER BY
    NLSSORT(b.NOM, 'NLS_SORT=FRENCH_M'),
    NLSSORT(b.PRENOM, 'NLS_SORT=FRENCH_M');
