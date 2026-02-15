-- ============================================================
-- Objet    : Index de performance pour la cartographie GPEEC
-- Contexte : Créés après analyse des plans d'exécution
--            des 4 vues principales
-- SGBD     : Oracle 19c
-- ============================================================
-- Principe : index composites couvrants pour éviter les
-- retours table (TABLE ACCESS BY INDEX ROWID) sur les
-- jointures et filtres les plus fréquents.
-- ============================================================

-- ─── Index simples ───

-- Temps partiel : recherche par dossier
CREATE INDEX IDX_TEMPS_PARTIEL_DOSSIER
    ON TEMPS_PARTIEL(NO_DOSSIER_PERS);

-- Spécialisations carrière : recherche par dossier
CREATE INDEX IDX_CAR_SPEC_DOSSIER
    ON CARRIERE_SPECIALISATIONS(NO_DOSSIER_PERS);

-- ─── Index composites (couvrants) ───
-- L'ordre des colonnes suit le pattern d'accès :
-- 1. Clé de jointure (NO_DOSSIER_PERS)
-- 2. Filtre d'état (TEM_ANNULATION / TEM_VALIDE)
-- 3. Bornes de dates (début, fin)

-- Contrats : jointure + filtre annulation + bornes dates
CREATE INDEX IDX_CONTRAT_COMPOSITE
    ON CONTRAT(
        NO_DOSSIER_PERS,
        TEM_ANNULATION,
        D_DEB_CONTRAT_TRAV,
        D_FIN_CONTRAT_TRAV
    );

-- Affectations : jointure + filtre validité + bornes dates
CREATE INDEX IDX_AFFECTATION_COMPOSITE
    ON AFFECTATION(
        NO_DOSSIER_PERS,
        TEM_VALIDE,
        D_DEB_AFFECTATION,
        D_FIN_AFFECTATION
    );

-- Carrière : jointure + filtre validité + bornes dates
CREATE INDEX IDX_CARRIERE_COMPOSITE
    ON CARRIERE(
        NO_DOSSIER_PERS,
        TEM_VALIDE,
        D_DEB_CARRIERE,
        D_FIN_CARRIERE
    );

-- Éléments de carrière : idem
CREATE INDEX IDX_ELT_CARRIERE_COMPOSITE
    ON ELEMENT_CARRIERE(
        NO_DOSSIER_PERS,
        TEM_VALIDE,
        D_DEB,
        D_FIN
    );

-- ─── Rafraîchissement des statistiques ───
-- Nécessaire après création d'index pour que l'optimiseur
-- Oracle les prenne en compte dans les plans d'exécution.

BEGIN
    DBMS_STATS.GATHER_TABLE_STATS('MANGUE', 'CHANGEMENT_POSITION');
    DBMS_STATS.GATHER_TABLE_STATS('MANGUE', 'DEPART');
    DBMS_STATS.GATHER_TABLE_STATS('MANGUE', 'TEMPS_PARTIEL');
END;
/
