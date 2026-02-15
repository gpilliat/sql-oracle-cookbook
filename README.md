
# SQL & PL/SQL Cookbook

Recueil de requêtes SQL et PL/SQL issues de mon expérience en environnement universitaire et grands comptes. Chaque requête est commentée, contextualisée et testée sur **Oracle 19c** et/ou **PostgreSQL 14+**.

L'objectif n'est pas d'être exhaustif mais de documenter des cas concrets : optimisations réelles, patterns de reporting, solutions à des problèmes rencontrés en production.

---

## Contenu

| Dossier | Description |
|---|---|
| `optimisation/` | Amélioration de performances : réécriture de requêtes, suppression de DISTINCT abusifs, index, EXPLAIN PLAN |
| `fenetrage/` | Fonctions analytiques : `ROW_NUMBER`, `LAG/LEAD`, `RANK`, `PARTITION BY` |
| `plsql/` | Procédures stockées, fonctions PL/SQL, `RESULT_CACHE` |
| `reporting/` | Requêtes décisionnelles : agrégations, pivots, indicateurs (RH, finances, scolarité) |
| `postgresql/` | Équivalents PostgreSQL, CTE récursives, JSONB |
| `utils/` | Requêtes utilitaires : dictionnaire Oracle, sessions, droits |
| `projets/gpeec/` | **Projet complet** : cartographie GPEEC — 4 vues Oracle, 15 fonctions PL/SQL, optimisation et indexation |

---

## Conventions

- Chaque fichier `.sql` est autonome et commenté
- Les données sont anonymisées (noms génériques, pas de données réelles)
- Le SGBD cible est indiqué en en-tête
- Formatage lisible : indentation, alias explicites

## Environnement

| | Version |
|---|---|
| Oracle | 19c |
| PostgreSQL | 14+ |
| Outils | SQL Developer, pgAdmin, DBeaver |
