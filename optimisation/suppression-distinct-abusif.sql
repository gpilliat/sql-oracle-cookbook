-- ============================================================
-- Titre   : Suppression de DISTINCT abusifs
-- Contexte : Vue de cartographie RH. 7 DISTINCT présents alors
--            que les jointures garantissent l'unicité des lignes.
-- SGBD    : Oracle 19c
-- Impact  : Suppression de tris inutiles sur ~1 500 lignes
-- ============================================================

-- ❌ AVANT : DISTINCT par réflexe
-- Le développeur d'origine a ajouté DISTINCT "au cas où"
-- sur chaque sous-requête. Le moteur trie systématiquement
-- les résultats pour éliminer les doublons inexistants.

SELECT DISTINCT
    a.no_dossier,
    a.nom,
    a.prenom,
    c.lib_grade,
    aff.lib_composante
FROM agents a
JOIN carriere c
    ON c.no_dossier = a.no_dossier
    AND c.tem_valide = 'O'
    AND SYSDATE BETWEEN c.d_deb AND NVL(c.d_fin, SYSDATE)
JOIN affectation aff
    ON aff.no_dossier = a.no_dossier
    AND aff.tem_valide = 'O'
    AND SYSDATE BETWEEN aff.d_deb AND NVL(aff.d_fin, SYSDATE);

-- ✅ APRÈS : sans DISTINCT
-- Les filtres de validité + bornes de dates garantissent
-- au plus une ligne par agent dans chaque table.
-- Vérifié par : SELECT no_dossier, COUNT(*) ... HAVING COUNT(*) > 1

SELECT
    a.no_dossier,
    a.nom,
    a.prenom,
    c.lib_grade,
    aff.lib_composante
FROM agents a
JOIN carriere c
    ON c.no_dossier = a.no_dossier
    AND c.tem_valide = 'O'
    AND SYSDATE BETWEEN c.d_deb AND NVL(c.d_fin, SYSDATE)
JOIN affectation aff
    ON aff.no_dossier = a.no_dossier
    AND aff.tem_valide = 'O'
    AND SYSDATE BETWEEN aff.d_deb AND NVL(aff.d_fin, SYSDATE);

-- Diagnostic : vérifier l'absence de doublons AVANT de retirer DISTINCT
-- Si cette requête retourne 0 lignes → DISTINCT est inutile

SELECT no_dossier, COUNT(*) AS nb
FROM (
    -- coller ici la requête SANS DISTINCT
)
GROUP BY no_dossier
HAVING COUNT(*) > 1;
