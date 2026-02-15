# Architecture — Cartographie GPEEC

## Vue d'ensemble

```mermaid
graph TD
    MAIN["<b>VUE_PRINCIPALE</b><br/>31 colonnes<br/>─────<br/>GET_POPULATION()<br/>GET_DATE_DERN_EMB()<br/>GET_DELEGATION()<br/>GET_MAD()<br/>GET_FORMATIONS()"]

    TIT["<b>VUE_TITULAIRES</b><br/>~1 500 agents<br/>─────<br/>GET_COMPOSANTE()<br/>GET_SERVICE()<br/>GET_SECTION_CNU_TIT()<br/>GET_NO_DISC_TIT()<br/>GET_LIB_CNU_TIT()<br/>GET_LIB_DISCIPLINE_TIT()"]

    CTR["<b>VUE_CONTRACTUELS</b><br/>~500 agents<br/>─────<br/>GET_COMPOSANTE()<br/>GET_SERVICE()<br/>GET_SECTION_CNU_CTR()<br/>GET_LIB_CNU_CTR()<br/>GET_LIB_DISCIPLINE_CTR()"]

    CGE["<b>VUE_CONGES</b><br/>Congés en cours<br/>→ Alimente POSITION 2"]

    REF["<b>Tables référentielles</b><br/>─────<br/>CONTRAT<br/>DEPART<br/>INDIVIDU_DIPLOMES (HDR)<br/>PERSONNEL_ULR"]

    FUNC["<b>GET_DOSSIERS_CTR()</b><br/>Fonction TABLE<br/>RESULT_CACHE"]

    UNION{{"UNION de 4 flux"}}

    CDD["CONTRAT +<br/>CONTRAT_AVENANT<br/>(CDD/CDI)"]
    HEB["CONTRAT_HEBERGES<br/>(hébergés)"]
    VAC["VACATAIRES ∩ CARRIERE<br/>(exceptions)"]
    EXT["PERSONNEL_ULR<br/>(externes)"]

    CGE_MAL["Congés maladie<br/>maternité"]
    CGE_ST["Congés sans<br/>traitement"]
    MTT["Mi-temps<br/>thérapeutique"]

    MAIN -->|"UNION ALL"| TIT
    MAIN -->|"LEFT JOIN"| CGE
    MAIN -->|"LEFT JOIN"| REF
    TIT -->|"UNION ALL"| CTR
    CTR -->|"Appelle"| FUNC
    FUNC --> UNION
    UNION --> CDD
    UNION --> HEB
    UNION --> VAC
    UNION --> EXT

    CGE --> CGE_MAL
    CGE --> CGE_ST
    CGE_ST --> MTT

    style MAIN fill:#dae8fc,stroke:#6c8ebf,stroke-width:2px
    style TIT fill:#dae8fc,stroke:#6c8ebf,stroke-width:2px
    style CTR fill:#dae8fc,stroke:#6c8ebf,stroke-width:2px
    style FUNC fill:#dae8fc,stroke:#6c8ebf,stroke-width:2px
    style CGE fill:#f8cecc,stroke:#b85450,stroke-width:2px
    style CGE_MAL fill:#f8cecc,stroke:#b85450
    style CGE_ST fill:#f8cecc,stroke:#b85450
    style MTT fill:#f8cecc,stroke:#b85450
    style REF fill:#d5e8d4,stroke:#82b366,stroke-width:2px
    style CDD fill:#dae8fc,stroke:#6c8ebf
    style HEB fill:#dae8fc,stroke:#6c8ebf
    style VAC fill:#dae8fc,stroke:#6c8ebf
    style EXT fill:#dae8fc,stroke:#6c8ebf
```

## Légende

| Couleur | Signification |
|---|---|
| 🔵 Bleu | Vues et fonctions PL/SQL (logique métier) |
| 🔴 Rouge | Données de congés |
| 🟢 Vert | Tables référentielles |

## Sources de données

| Alias dans la vue | Table/Vue source | Rôle |
|---|---|---|
| `ENS_AGT` | Union TITULAIRES + CONTRACTUELS | Données principales agents |
| `ENS_PRS` | PERSONNEL_ULR | Code poste, métadonnées (TXT_LIBRE) |
| `VUE_EMB` | CONTRAT | Date de 1ère embauche |
| `VUE_CDI` | CONTRAT | Date de passage CDI |
| `VUE_DEP` | DEPART | Date de départ |
| `VUE_HDR` | INDIVIDU_DIPLOMES | Habilitation à Diriger des Recherches |
| `VUE_CGE` | VUE_CONGES | Congés en cours |
