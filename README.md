# SQL & PL/SQL Cookbook (Oracle / PostgreSQL)

Recueil de requêtes SQL et PL/SQL issues d'expériences en environnements universitaires et grands comptes. Ce dépôt centralise des solutions techniques répondant à des problématiques de pilotage, d'intégration et d'optimisation de données.

Le contenu est organisé par projets réels anonymisés, documentant des cas concrets de tuning, de reporting décisionnel et de mise en cohérence de données hétérogènes.

* **SGBD principal** : Oracle 19c
* **Variantes** : PostgreSQL 14+ (pour certains modules)

---

## Projets documentés

| Projet | Dossier | Contenu | Focus Technique |
| :--- | :--- | :--- | :--- |
| **GPEEC (RH)** | [`projets/gpeec/`](./projets/gpeec/) | Vues Oracle, architecture Mermaid, indexation, diagnostic qualité | **Tuning SQL** : réécriture pour performance (gain > 40s), index composites, fonctions PL/SQL avec `RESULT_CACHE`. |
| **ABYLA-TOS (Salles)** | [`projets/abyla-tos/`](./projets/abyla-tos/) | Scripts DDL, schémas de migration, contrôles d'intégrité | **Data Integrity** : normalisation de schémas, gestion de clés composites et jointures sur données hétérogènes. |
| **DAF-MISSIONS (Finance)** | [`projets/daf-missions/`](./projets/daf-missions/) | Vue consolidée "360° missions" | **Architecture SQL** : modularité par CTE (Common Table Expressions), agrégations multi-sources, sécurisation `LISTAGG`. |
| **QVT-AGENTS (IAM)** | [`projets/qvt-agents/`](./projets/qvt-agents/) | Vue agents permanents, règles métier de gestion d'accès | **Analyse de données** : dédoublonnage par fonctions analytiques (`ROW_NUMBER`), gestion d'historique et sélection d'avenants. |

Chaque projet contient un fichier `README.md` spécifique détaillant le contexte métier, les contraintes techniques et les choix d'implémentation.

---

## Techniques mises en œuvre

* **SQL Analytique** : Utilisation intensive de `ROW_NUMBER`, `RANK`, `LAG/LEAD` et du partitionnement pour l'analyse de séries temporelles et de carrières.
* **Structuration** : Organisation du code par CTE pour favoriser la lisibilité et la maintenance des requêtes complexes.
* **Qualité de données** : Mise en place de contrôles croisés, détection d'anomalies (dates aberrantes, types de contrats) et normalisation (gestion des accents, formats d'emails).
* **Performance** : Diagnostic via plans d'exécution (`EXPLAIN PLAN`), réduction des coûts d'IO (suppression des `DISTINCT` inutiles), et patterns d'indexation couvrante.
* **DDL et Migration** : Scripts de création et de transformation de schémas, gestion des contraintes d'intégrité et des types de données spécifiques.

---

## Conventions et Qualité

* **Autonomie** : Chaque script `.sql` est conçu pour être autonome et documenté par commentaires intégrés.
* **Anonymisation** : Toutes les données, identifiants et libellés sensibles ont été remplacés par des valeurs génériques.
* **Portabilité** : Le SGBD cible est systématiquement indiqué en en-tête lorsque la syntaxe est spécifique (notamment pour les fonctions PL/SQL ou les extensions PostgreSQL).

---

## Environnement technique

| Composant | Version / Outil |
| :--- | :--- |
| **SGBD** | Oracle 19c, PostgreSQL 14+ |
| **Outils** | SQL Developer, DBeaver, pgAdmin |
| **Modélisation** | Schémas au format Mermaid |
