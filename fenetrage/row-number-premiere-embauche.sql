-- ============================================================
-- Titre   : Extraire la première embauche par agent
-- Contexte : Parmi N contrats par agent, on veut la date
--            du tout premier contrat non annulé.
-- SGBD    : Oracle 19c / Compatible PostgreSQL 14+
-- Pattern : ROW_NUMBER() + filtre RN = 1
-- ============================================================

-- Pattern classique : ROW_NUMBER pour garder une seule ligne
-- par groupe (ici : par agent), ordonnée par un critère.

SELECT
    no_dossier,
    date_debut,
    reference_contrat
FROM (
    SELECT
        no_dossier_pers            AS no_dossier,
        d_deb_contrat_trav         AS date_debut,
        reference_contrat,
        ROW_NUMBER() OVER (
            PARTITION BY no_dossier_pers
            ORDER BY d_deb_contrat_trav ASC
        )                          AS rn
    FROM contrat
    WHERE tem_annulation = 'N'
)
WHERE rn = 1;

-- Variante : si on veut le DERNIER contrat → ORDER BY ... DESC

-- Note : ce pattern est utilisé dans la vue GPEEC pour
-- calculer la date de 1ère embauche (VUE_EMB).
-- Voir projets/gpeec/vues/vue_principale.sql
