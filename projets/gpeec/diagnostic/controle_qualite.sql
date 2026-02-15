-- ============================================================
-- Objet    : Requêtes de diagnostic et contrôle qualité
-- Contexte : Vérifications post-optimisation des vues GPEEC
-- SGBD     : Oracle 19c
-- ============================================================

-- ─── 1. Vérifier la volumétrie des vues ───

SELECT 'TITULAIRES'   AS SOURCE, COUNT(*) AS NB FROM VUE_TITULAIRES
UNION ALL
SELECT 'CONTRACTUELS' AS SOURCE, COUNT(*) AS NB FROM VUE_CONTRACTUELS
UNION ALL
SELECT 'PRINCIPALE'   AS SOURCE, COUNT(*) AS NB FROM VUE_PRINCIPALE;


-- ─── 2. Détecter les codes poste non reconnus ───

SELECT
    CODE_POSTE,
    COUNT(*) AS NB_AGENTS
FROM VUE_PRINCIPALE
WHERE CODE_POSTE = '!No match!'
GROUP BY CODE_POSTE;


-- ─── 3. Lister les agents sans code poste reconnu ───
-- Utile pour identifier les codes manquants à ajouter au pattern REGEX

SELECT
    AGT.NO_DOSSIER,
    AGT.NOM,
    AGT.PRENOM,
    PRS.TXT_LIBRE
FROM VUE_PRINCIPALE AGT
JOIN PERSONNEL_ULR PRS
    ON AGT.NO_DOSSIER = PRS.NO_DOSSIER_PERS
WHERE AGT.CODE_POSTE = '!No match!'
ORDER BY PRS.TXT_LIBRE;


-- ─── 4. Détecter les dates aberrantes dans les contrats ───

SELECT
    NO_DOSSIER_PERS,
    D_DEB_CONTRAT_TRAV,
    D_FIN_CONTRAT_TRAV,
    D_FIN_ANTICIPEE
FROM CONTRAT
WHERE TEM_ANNULATION = 'N'
  AND (
    D_DEB_CONTRAT_TRAV < DATE '1950-01-01'
    OR D_FIN_CONTRAT_TRAV < DATE '1950-01-01'
    OR D_FIN_ANTICIPEE < DATE '1950-01-01'
  );


-- ─── 5. Vérifier que les index sont utilisés ───
-- Lancer après un SELECT sur la vue principale

EXPLAIN PLAN FOR
SELECT * FROM VUE_PRINCIPALE WHERE NO_INDIVIDU = '12345';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);


-- ─── 6. Vérifier l'état des statistiques ───

SELECT
    TABLE_NAME,
    NUM_ROWS,
    LAST_ANALYZED
FROM ALL_TAB_STATISTICS
WHERE OWNER = 'MANGUE'
  AND TABLE_NAME IN (
    'CONTRAT', 'CARRIERE', 'AFFECTATION',
    'ELEMENT_CARRIERE', 'CHANGEMENT_POSITION',
    'DEPART', 'TEMPS_PARTIEL'
  )
ORDER BY TABLE_NAME;


-- ─── 7. Compter les doublons potentiels ───
-- Agents présents à la fois dans TITULAIRES et CONTRACTUELS
-- (ne devrait jamais arriver : ensembles disjoints)

SELECT NO_DOSSIER, COUNT(*) AS NB
FROM (
    SELECT NO_DOSSIER FROM VUE_TITULAIRES
    INTERSECT
    SELECT NO_DOSSIER FROM VUE_CONTRACTUELS
)
GROUP BY NO_DOSSIER;
