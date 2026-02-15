-- ============================================================
-- Titre   : Fonction TABLE avec RESULT_CACHE
-- Contexte : Retourner l'ensemble des dossiers contractuels
--            depuis 4 sources différentes (UNION).
--            Appelée par la vue contractuels pour chaque ligne
--            → sans cache, exécutée des centaines de fois.
-- SGBD    : Oracle 19c (RESULT_CACHE = spécifique Oracle)
-- ============================================================

-- ─── Type de retour ───
CREATE OR REPLACE TYPE t_dossier_list AS TABLE OF VARCHAR2(20);
/

-- ─── Fonction ───
CREATE OR REPLACE FUNCTION get_dossiers_ctr
    RETURN t_dossier_list
    RESULT_CACHE                    -- ← Oracle met en cache le résultat
IS
    v_result t_dossier_list := t_dossier_list();
BEGIN
    -- Flux 1 : CDD/CDI (contrats actifs non annulés)
    FOR r IN (
        SELECT DISTINCT c.no_dossier_pers AS no_dossier
        FROM contrat c
        JOIN contrat_avenant ca ON ca.no_seq_contrat = c.no_seq_contrat
        WHERE c.tem_annulation = 'N'
          AND NVL(c.d_fin_contrat_trav, SYSDATE) >= TRUNC(SYSDATE)
    ) LOOP
        v_result.EXTEND;
        v_result(v_result.COUNT) := r.no_dossier;
    END LOOP;

    -- Flux 2 : Hébergés
    FOR r IN (
        SELECT DISTINCT no_dossier_pers AS no_dossier
        FROM contrat_heberges
        WHERE NVL(d_fin, SYSDATE) >= TRUNC(SYSDATE)
    ) LOOP
        v_result.EXTEND;
        v_result(v_result.COUNT) := r.no_dossier;
    END LOOP;

    -- Flux 3 : Vacataires avec carrière active
    FOR r IN (
        SELECT DISTINCT v.no_dossier_pers AS no_dossier
        FROM vacataires v
        JOIN carriere c ON c.no_dossier_pers = v.no_dossier_pers
        WHERE c.tem_valide = 'O'
          AND SYSDATE BETWEEN c.d_deb_carriere
              AND NVL(c.d_fin_carriere, SYSDATE)
    ) LOOP
        v_result.EXTEND;
        v_result(v_result.COUNT) := r.no_dossier;
    END LOOP;

    -- Flux 4 : Personnels externes (filtrés par code dans TXT_LIBRE)
    FOR r IN (
        SELECT DISTINCT no_dossier_pers AS no_dossier
        FROM personnel_ulr
        WHERE REGEXP_LIKE(txt_libre, '#IN-C|#IN-H|#IN-V')
          AND NOT REGEXP_LIKE(txt_libre, '#EXIT#')
    ) LOOP
        v_result.EXTEND;
        v_result(v_result.COUNT) := r.no_dossier;
    END LOOP;

    RETURN v_result;
END get_dossiers_ctr;
/

-- ─── Utilisation dans une vue ───
-- SELECT * FROM TABLE(get_dossiers_ctr());

-- Note sur RESULT_CACHE :
-- - Le cache est invalidé automatiquement quand les tables
--   sous-jacentes sont modifiées (DML).
-- - Pas besoin de purge manuelle.
-- - Vérifiable avec : SELECT * FROM V$RESULT_CACHE_STATISTICS;
