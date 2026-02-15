# Projet GPEEC — Cartographie des Emplois et des Effectifs

*Optimisation de vues RH complexes : index composites, Result Cache, extraction Regex — temps de réponse réduit de 45s à < 1s.*

## Contexte

Refonte et optimisation d'un système de cartographie RH pour un établissement d'enseignement supérieur (~2 000 agents). Le système alimente les tableaux de bord de la DRH pour le pilotage des emplois, effectifs et compétences (GPEEC).

**Durée :** 2 mois de développement, en production depuis.
**SGBD :** Oracle 19c
**Application métier source :** Progiciel RH (schémas MANGUE / GRHUM)

---

## Architecture

```
VUE_PRINCIPALE (31 colonnes — consolidation finale)
│
├── UNION ALL
│   ├── VUE_TITULAIRES  (~1 500 agents)
│   │   └── Appelle 6 fonctions PL/SQL
│   │
│   └── VUE_CONTRACTUELS (~500 agents)
│       ├── Appelle 5 fonctions PL/SQL
│       └── GET_DOSSIERS_CTR() — fonction TABLE
│           └── UNION de 4 flux (CDD/CDI, hébergés, vacataires, externes)
│
├── LEFT JOIN VUE_CONGES (congés en cours)
│   ├── Congés maladie / maternité
│   ├── Congés sans traitement
│   └── Mi-temps thérapeutique
│
├── LEFT JOIN Tables référentielles
│   ├── Référentiel personnel (code poste, métadonnées)
│   ├── Contrats (1ère embauche, passage CDI)
│   ├── Départs
│   └── Diplômes (HDR)
│
└── Appelle 5 fonctions PL/SQL transversales
    ├── GET_POPULATION()      → Classification E-EC / BIATSS
    ├── GET_DATE_DERN_EMB()   → Dernière embauche
    ├── GET_DELEGATION()      → Délégation éventuelle
    ├── GET_MAD()             → Mise à disposition
    └── GET_FORMATIONS()      → Liste des formations suivies
```

Voir le [diagramme complet](schema_architecture.md) pour le détail des flux.

---

## Travail réalisé

### 1. Optimisation des vues

Les vues existantes présentaient des problèmes de performance (temps de réponse > 45s sur certaines requêtes).

**Problèmes identifiés et corrigés :**

| Problème | Vue | Impact |
|---|---|---|
| 7 `DISTINCT` abusifs | Titulaires | Tris inutiles sur ~1 500 lignes |
| 5 `DISTINCT` abusifs | Contractuels | Idem ~500 lignes |
| 4 `DISTINCT` abusifs | Congés | Idem |
| Syntaxe Oracle obsolète (`,` + `WHERE`) | Toutes | Lisibilité, maintenabilité |
| `DECODE` au lieu de `CASE/NVL` | Toutes | Lisibilité |
| Accès multiples aux mêmes tables | Toutes | I/O inutiles |
| Alias `add` (mot réservé Oracle) | Contractuels | Risque d'erreur |

**Optimisations appliquées :**
- Conversion syntaxe Oracle propriétaire → **ANSI SQL** (`LEFT JOIN ... ON`)
- Remplacement `DECODE` → `CASE` / `NVL`
- Factorisation des accès tables via **CTE** (`WITH`)
- Ajout `RESULT_CACHE` sur la fonction TABLE `GET_DOSSIERS_CTR`

### 2. Création d'index

6 index créés pour couvrir les patterns d'accès les plus fréquents :

```sql
-- Index simples
CREATE INDEX IDX_TEMPS_PARTIEL_DOSSIER
    ON TEMPS_PARTIEL(NO_DOSSIER_PERS);

CREATE INDEX IDX_CAR_SPEC_DOSSIER
    ON CARRIERE_SPECIALISATIONS(NO_DOSSIER_PERS);

-- Index composites (couvrants)
CREATE INDEX IDX_CONTRAT_COMPOSITE
    ON CONTRAT(NO_DOSSIER_PERS, TEM_ANNULATION, D_DEB_CONTRAT_TRAV, D_FIN_CONTRAT_TRAV);

CREATE INDEX IDX_AFFECTATION_COMPOSITE
    ON AFFECTATION(NO_DOSSIER_PERS, TEM_VALIDE, D_DEB_AFFECTATION, D_FIN_AFFECTATION);

CREATE INDEX IDX_CARRIERE_COMPOSITE
    ON CARRIERE(NO_DOSSIER_PERS, TEM_VALIDE, D_DEB_CARRIERE, D_FIN_CARRIERE);

CREATE INDEX IDX_ELT_CARRIERE_COMPOSITE
    ON ELEMENT_CARRIERE(NO_DOSSIER_PERS, TEM_VALIDE, D_DEB, D_FIN);
```

Statistiques rafraîchies sur les tables impactées après indexation.

### 3. Correction de données

**Dates aberrantes détectées :**

| Dossier | Valeur erronée | Valeur attendue |
|---|---|---|
| Agent A | 04/07/**1108** | 04/07/**2008** |
| Agent B | 01/09/**1010** | 01/09/**2010** |

Résolution : invalidation des contrats erronés (`TEM_ANNULATION = 'O'`), validée avec le référent métier.

### 4. Enrichissement des codes composante

Le champ "code poste" est extrait par REGEX depuis un champ texte libre. 18 codes manquants provoquaient un affichage "!No match!" pour 105 agents.

**Avant :** 43 codes reconnus
**Après :** 61 codes reconnus (+18), validés individuellement avec le référent métier.

---

## Fichiers

```
projets/gpeec/
├── README.md                          ← Ce fichier
├── schema_architecture.md             ← Diagramme d'architecture (Mermaid)
├── vues/
│   ├── vue_principale.sql             ← Vue de consolidation (31 colonnes)
│   ├── vue_titulaires.sql             ← Titulaires (~1 500 agents)
│   ├── vue_contractuels.sql           ← Contractuels (~500 agents)
│   └── vue_conges.sql                 ← Congés en cours
├── fonctions/
│   ├── get_population.sql             ← Classification E-EC / BIATSS
│   ├── get_dossiers_ctr.sql           ← Fonction TABLE (4 flux UNION)
│   ├── get_composante.sql
│   ├── get_service.sql
│   └── ...                            ← 15 fonctions au total
├── index/
│   └── creation_index.sql             ← 6 index de performance
└── diagnostic/
    └── controle_qualite.sql           ← Requêtes de vérification des données
```

---

## Points techniques notables

**Fonctions PL/SQL dans le SELECT — context switch assumé** — La vue
appelle ~5 fonctions PL/SQL par ligne (`GET_POPULATION`, `GET_DELEGATION`,
etc.). En Oracle, chaque appel provoque un context switch SQL → PL/SQL
qui peut être coûteux sur de gros volumes. Avec ~2 000 agents, l'impact
est négligeable (< 0.5s total). Sur un volume > 100 000 lignes, il faudrait
soit utiliser `PRAGMA UDF` (Oracle 12c+) pour réduire le coût du switch,
soit inliner la logique en SQL pur, soit basculer sur des sous-requêtes
scalaires corrélées.

**Fonction TABLE avec RESULT_CACHE** — La fonction `GET_DOSSIERS_CTR` retourne l'ensemble des dossiers contractuels via un `UNION` de 4 sources (CDD/CDI, hébergés, vacataires, personnels externes). L'ajout de `RESULT_CACHE` évite de recalculer ce résultat à chaque appel.

**Extraction REGEX depuis champ texte libre** — Le code poste UHA est stocké dans un champ texte non structuré (`TXT_LIBRE`). L'extraction repose sur `REGEXP_SUBSTR` avec un pattern de 61 codes validés. Ce type de contournement est fréquent sur les progiciels RH où le modèle de données ne prévoit pas tous les besoins locaux.

**Classification par règles en cascade** — La fonction `GET_POPULATION` détermine si un agent est E-EC (Enseignant-Chercheur) ou BIATSS via une cascade de tests : flag enseignant, tags dans le texte libre, patterns dans le type de contrat et le grade. L'ordre des tests est critique.

**Sécurité et RGPD** — La vue manipule des données RH à caractère personnel
(identité, affectation, contrats). L'accès est restreint via des rôles Oracle
aux seuls agents de la DRH habilités. Aucune donnée sensible (NIR, salaire)
n'est exposée dans la vue de reporting — seules les données nécessaires au
pilotage des emplois et effectifs sont restituées.

---

## Enseignements

Ce projet illustre plusieurs réalités du SI en établissement public :
- Les données RH sont réparties sur plusieurs schémas et tables, avec des conventions héritées
- Les progiciels métier ne couvrent pas 100% des besoins → contournements locaux (champ texte libre, vues custom)
- L'optimisation SQL a un impact direct sur l'expérience utilisateur quand les vues alimentent des tableaux de bord consultés quotidiennement
- La documentation et la collaboration avec le référent métier sont aussi importants que le code
