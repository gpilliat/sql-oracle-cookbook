# SQL & PL/SQL Cookbook (Oracle / PostgreSQL)

Recueil de requêtes SQL et PL/SQL issues de mon expérience en environnement universitaire et grands comptes.
Le contenu est organisé par **projets réels anonymisés** : vues décisionnelles, contrôles qualité, migrations de schéma et optimisation.

- SGBD : **Oracle 19c** (principal) ; certains éléments ont des variantes/équivalents **PostgreSQL 14+**
- Objectif : documenter des cas concrets (tuning, reporting, intégration), avec contexte et choix techniques

## Projets documentés

| Projet | Dossier | Contenu | Ce que ça démontre |
|---|---|---|---|
| **GPEEC (RH)** | [`projets/gpeec/`](./projets/gpeec/) | README, schéma/architecture (Mermaid), vues Oracle, index, diagnostic qualité | Vues complexes, optimisation (réécritures, index composites), règles métier RH |
| **ABYLA-TOS (salles / occupation)** | [`projets/abyla-tos/`](./projets/abyla-tos/) | Migration de schéma, reporting TOS, contrôle qualité | Migration DDL, import régulier, pièges Oracle, contrôles d’intégrité |
| **DAF-MISSIONS (finance)** | [`projets/daf-missions/`](./projets/daf-missions/) | Vue “360° missions” | CTE multiples, agrégations robustes, cohérence financière, patterns de lisibilité |
| **QVT-AGENTS (permanents)** | [`projets/qvt-agents/`](./projets/qvt-agents/) | Vue agents + règles métier | Dé-doublonnage, gestion d’historique, sélection “avenant le plus récent” (ROW_NUMBER) |

> Chaque projet contient son propre `README.md` avec le contexte, les choix, et les fichiers principaux.

## Techniques couvertes (exemples)
- SQL analytique : `ROW_NUMBER`, `RANK`, `LAG/LEAD`, partitionnement
- Structuration : CTE, découpage “lisible”, conventions d’alias
- Qualité de données : contrôles croisés, détection d’anomalies, règles métier
- Performance : réécritures SQL, indexation, réduction de `DISTINCT`, patterns d’agrégation
- DDL/migration : scripts de migration, pièges (mots réservés, encodage)

## Conventions
- Chaque fichier `.sql` est autonome et commenté
- Données et identifiants **anonymisés** (noms génériques, pas de données personnelles)
- Le SGBD cible est indiqué en en-tête quand pertinent

## Environnement
| | Version |
|---|---|
| Oracle | 19c |
| PostgreSQL | 14+ |
| Outils | SQL Developer, DBeaver, pgAdmin |
