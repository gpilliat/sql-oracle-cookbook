-- ============================================================
-- Vue      : VUE_PRINCIPALE (Cartographie GPEEC)
-- Objet    : Consolidation des données RH pour le pilotage
--            des emplois, effectifs et compétences
-- Colonnes : 31
-- Agents   : ~2 000 (titulaires + contractuels)
-- SGBD     : Oracle 19c
-- ============================================================
-- Architecture :
--   UNION ALL de VUE_TITULAIRES + VUE_CONTRACTUELS
--   LEFT JOIN sur congés, contrats, départs, diplômes, référentiel
--   Appel à 5 fonctions PL/SQL transversales
-- ============================================================

CREATE OR REPLACE VIEW VUE_PRINCIPALE (
    NO_INDIVIDU,
    CODE_POSTE,
    NOM,
    PRENOM,
    PATRONYME,
    GENRE,
    DATE_NAISSANCE,
    POPULATION,
    STATUT,
    CARTO_GRADE,
    GRADE,
    CATEGORIE,
    QUOT_TPP,
    QUOT_AFF,
    QUOT_POSTE,
    POSITION_1,
    POSITION_2,
    DERNIERE_EMBAUCHE,
    DATE_DEBUT_ETAB,
    DATE_DEPART,
    DATE_FIN_CONTRAT,
    CORPS,
    TYPE_CONTRAT,
    REFERENCE_CONTRAT,
    DATE_PASSAGE_CDI,
    AFFECTATION_COMPOSANTE,
    AFFECTATION_SERVICE,
    DATE_AFFECTATION,
    FORMATIONS,
    NUM_CNU_DISC,
    SECTION_CNU_DISC,
    HDR
) AS
SELECT
    -- ─── Identification ───
    AGT.NO_DOSSIER                                           AS NO_INDIVIDU,

    -- Code poste : extraction REGEX depuis champ texte libre
    -- Le progiciel RH ne prévoit pas ce champ → contournement local
    -- Pattern : 61 codes composante validés avec le référent métier
    CASE
        WHEN AGT.ENSEIGNANT = 'O'                            THEN 'X'
        WHEN INSTR(UPPER(PRS.TXT_LIBRE), '#ENS#') > 0       THEN 'X'
        WHEN REGEXP_LIKE(UPPER(AGT.TYPE_CONTRAT),
             'CONTRACTUEL.*CHERCHEUR|DOCTORANT|MCF|TUDIANT|SAISONNIER')
                                                             THEN 'X'
        WHEN REGEXP_LIKE(UPPER(AGT.GRADE),
             'CONTRACTUEL DOCTORANT|ENSEIGNANT')             THEN 'X'
        WHEN REGEXP_LIKE(PRS.TXT_LIBRE, 'CNRS\.')           THEN 'X'
        WHEN REGEXP_LIKE(PRS.TXT_LIBRE, 'NEF\.')            THEN 'X'
        WHEN REGEXP_LIKE(PRS.TXT_LIBRE,
             '^(CODE1|CODE2|CODE3|...|CODE61)\.')            THEN
            REGEXP_SUBSTR(PRS.TXT_LIBRE, '([^\s|#]+)')
        ELSE '!No match!'
    END                                                      AS CODE_POSTE,

    UPPER(AGT.NOM)                                           AS NOM,
    AGT.PRENOM                                               AS PRENOM,
    AGT.PATRONYME                                            AS PATRONYME,
    AGT.CIV                                                  AS GENRE,
    AGT.NAISSANCE                                            AS DATE_NAISSANCE,

    -- ─── Classification ───
    -- Fonction PL/SQL : cascade de règles pour déterminer E-EC ou BIATSS
    GET_POPULATION(AGT.ENSEIGNANT,
                   PRS.TXT_LIBRE,
                   AGT.TYPE_CONTRAT,
                   AGT.GRADE)                                AS POPULATION,

    -- Statut avec détection de cas particuliers dans le texte libre
    CASE
        WHEN AGT.STATUT <> 'TIT' THEN
            CASE
                WHEN REGEXP_LIKE(UPPER(PRS.TXT_LIBRE), 'MS')   THEN 'MS'
                WHEN REGEXP_LIKE(UPPER(PRS.TXT_LIBRE), 'CL')   THEN 'CL'
                WHEN REGEXP_LIKE(UPPER(PRS.TXT_LIBRE), '.APP')  THEN 'APP'
                ELSE AGT.STATUT
            END
        ELSE 'TIT'
    END                                                      AS STATUT,

    AGT.CARTO_GRADE                                          AS CARTO_GRADE,
    AGT.GRADE                                                AS GRADE,
    AGT.CATEGORIE                                            AS CATEGORIE,

    -- ─── Quotités ───
    -- Mises à 0% si l'agent est en disponibilité ou détachement
    CASE
        WHEN AGT.POSITION IN ('Disponibilité', 'Détachement') THEN '0 %'
        ELSE NVL(TO_CHAR(AGT.QUOT_TPP) || ' %', '100 %')
    END                                                      AS QUOT_TPP,

    CASE
        WHEN AGT.POSITION IN ('Disponibilité', 'Détachement') THEN '0 %'
        ELSE NVL(TO_CHAR(AGT.QUOT_AFF) || ' %', '100 %')
    END                                                      AS QUOT_AFF,

    CASE
        WHEN AGT.POSITION IN ('Disponibilité', 'Détachement') THEN '0 %'
        ELSE NVL(TO_CHAR(AGT.QUOT_POSTE) || ' %', '100 %')
    END                                                      AS QUOT_POSTE,

    -- ─── Positions ───
    AGT.POSITION                                             AS POSITION_1,

    -- Position 2 : concaténation congés + délégation + mise à disposition
    VUE_CGE.LIB_CONGE
        || GET_DELEGATION(AGT.NO_DOSSIER)
        || GET_MAD(AGT.NO_DOSSIER)                           AS POSITION_2,

    -- ─── Dates clés ───
    GET_DATE_DERN_EMB(AGT.NO_DOSSIER)                        AS DERNIERE_EMBAUCHE,
    VUE_EMB.DATE_1ERE_EMBAUCHE                               AS DATE_DEBUT_ETAB,
    VUE_DEP.DATE_DEPART                                      AS DATE_DEPART,
    AGT.DATE_FIN_CONTRAT                                     AS DATE_FIN_CONTRAT,

    -- ─── Contrat ───
    AGT.CORPS                                                AS CORPS,
    AGT.TYPE_CONTRAT                                         AS TYPE_CONTRAT,
    AGT.REFERENCE_CONTRAT                                    AS REFERENCE_CONTRAT,
    VUE_CDI.DATE_CDI                                         AS DATE_PASSAGE_CDI,

    -- ─── Affectation ───
    AGT.COMPOSANTE                                           AS AFFECTATION_COMPOSANTE,
    AGT.SERVICE                                              AS AFFECTATION_SERVICE,
    AGT.DATE_AFFECTATION                                     AS DATE_AFFECTATION,

    -- ─── Formations & Recherche ───
    GET_FORMATIONS(AGT.NO_DOSSIER)                           AS FORMATIONS,

    -- CNU/discipline : masqué pour les BIATSS
    CASE
        WHEN GET_POPULATION(AGT.ENSEIGNANT, PRS.TXT_LIBRE,
             AGT.TYPE_CONTRAT, AGT.GRADE) = 'BIATSS'        THEN 'X'
        ELSE AGT.NO_CNU_DISC
    END                                                      AS NUM_CNU_DISC,

    CASE
        WHEN GET_POPULATION(AGT.ENSEIGNANT, PRS.TXT_LIBRE,
             AGT.TYPE_CONTRAT, AGT.GRADE) = 'BIATSS'        THEN 'X'
        ELSE AGT.LIB_CNU_DISC
    END                                                      AS SECTION_CNU_DISC,

    -- HDR (Habilitation à Diriger des Recherches)
    CASE
        WHEN VUE_HDR.HDR = 'OUI' THEN 'OUI'
        ELSE 'X'
    END                                                      AS HDR

FROM (
    -- ─── Source principale : UNION des titulaires et contractuels ───
    SELECT * FROM VUE_TITULAIRES
    UNION ALL
    SELECT * FROM VUE_CONTRACTUELS
    WHERE NO_DOSSIER <> '99999'  -- compte test exclu
) AGT

-- Référentiel personnel (code poste dans TXT_LIBRE)
LEFT JOIN PERSONNEL_ULR PRS
    ON AGT.NO_DOSSIER = PRS.NO_DOSSIER_PERS

-- Date de 1ère embauche (contrat le plus ancien non annulé)
LEFT JOIN (
    SELECT
        NO_DOSSIER,
        TO_CHAR(DATE_1ERE_EMBAUCHE, 'DD/MM/YYYY') AS DATE_1ERE_EMBAUCHE
    FROM (
        SELECT
            NO_DOSSIER_PERS                        AS NO_DOSSIER,
            MIN(D_DEB_CONTRAT_TRAV)                AS DATE_1ERE_EMBAUCHE,
            ROW_NUMBER() OVER (
                PARTITION BY NO_DOSSIER_PERS
                ORDER BY D_DEB_CONTRAT_TRAV ASC
            )                                      AS RN
        FROM CONTRAT
        WHERE TEM_ANNULATION = 'N'
        GROUP BY NO_DOSSIER_PERS, NO_SEQ_CONTRAT, D_DEB_CONTRAT_TRAV
    )
    WHERE RN = 1
) VUE_EMB
    ON AGT.NO_DOSSIER = VUE_EMB.NO_DOSSIER

-- Date de passage CDI (contrat sans date de fin)
LEFT JOIN (
    SELECT
        NO_DOSSIER_PERS                            AS NO_DOSSIER,
        TO_CHAR(MAX(D_DEB_CONTRAT_TRAV), 'DD/MM/YYYY') AS DATE_CDI
    FROM CONTRAT
    WHERE D_FIN_CONTRAT_TRAV IS NULL
      AND TEM_ANNULATION = 'N'
    GROUP BY NO_DOSSIER_PERS
) VUE_CDI
    ON AGT.NO_DOSSIER = VUE_CDI.NO_DOSSIER

-- Date de départ
LEFT JOIN (
    SELECT
        NO_DOSSIER_PERS                            AS NO_DOSSIER,
        TO_CHAR(MAX(D_EFFET_DEPART), 'DD/MM/YYYY') AS DATE_DEPART
    FROM DEPART
    WHERE TEM_VALIDE = 'O'
    GROUP BY NO_DOSSIER_PERS
) VUE_DEP
    ON AGT.NO_DOSSIER = VUE_DEP.NO_DOSSIER

-- HDR
LEFT JOIN (
    SELECT
        NO_INDIVIDU                                AS NO_DOSSIER,
        'OUI'                                      AS HDR
    FROM INDIVIDU_DIPLOMES
    WHERE TEM_VALIDE = 'O'
      AND C_TITULAIRE_DIPLOME = 'T'
      AND C_DIPLOME = '0731000'
    GROUP BY NO_INDIVIDU
) VUE_HDR
    ON AGT.NO_DOSSIER = VUE_HDR.NO_DOSSIER

-- Congés en cours
LEFT JOIN VUE_CONGES VUE_CGE
    ON AGT.NO_DOSSIER = VUE_CGE.NO_DOSSIER
;
