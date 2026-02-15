# Projet ABYLA-TOS — Référentiel des salles et taux d'occupation

*Réconciliation de référentiels hétérogènes (Planification vs Patrimoine) et reporting décisionnel Oracle.*

## Contexte

Projet complet couvrant toute la chaîne : de l'import du référentiel patrimonial
des salles jusqu'au reporting du taux d'occupation pour le Pilotage institutionnel.

**Ce que j'ai fait :**
- Évolution du schéma Oracle (8 → 12 colonnes) pour intégrer les nouvelles données patrimoine
- Procédure d'import CSV depuis les fichiers Excel du service patrimoine
- Requêtes de reporting croisant planification (ADE) et patrimoine (ABYLA)
- Contrôle qualité automatisé pour détecter les incohérences entre les deux référentiels

---

## Architecture du projet

```
Fichier Excel (patrimoine)
        │
        ▼
┌──────────────────────┐
│ 1. IMPORT CSV        │  Évolution DDL + chargement
│    → Oracle          │  (migration-schema.md)
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐     ┌──────────────────────┐
│ Table REFERENTIEL    │     │ Tables ADESTATS      │
│ SALLES (ABYLA)       │     │ (planification ADE)  │
│ 466 salles           │     │ ~90 000 activités/an │
└──────────┬───────────┘     └──────────┬───────────┘
           │                            │
           └────────────┬───────────────┘
                        │
                        ▼
              ┌──────────────────┐
              │ 2. REPORTING TOS │  Croisement ABYLA × ADE
              │    → ReportServer│  (reporting-tos.md)
              └──────────┬───────┘
                         │
                         ▼
              ┌──────────────────┐
              │ 3. CONTRÔLE      │  Détection des salles
              │    QUALITÉ       │  non référencées
              │                  │  (controle-qualite.md)
              └──────────────────┘
```

---

## Contenu du dossier

| Fichier | Description |
|---|---|
| `migration-schema.md` | Évolution DDL (avant/après), script de migration, procédure d'import CSV |
| `reporting-tos.md` | Extraction TOS : specs fonctionnelles + requête SQL |
| `controle-qualite.md` | Détection des salles ADE sans correspondance ABYLA |

---

## Notes techniques

### Jointure par nom normalisé

La requête de reporting utilise une jointure sur le nom normalisé des salles :

```sql
LEFT JOIN REFERENTIEL_SALLES ref
    ON UPPER(TRIM(ref.NOM_PLANIFICATION)) = UPPER(TRIM(cl.NAME))
```

**Choix assumé :** avec ~466 salles dans le référentiel, le full table scan
reste largement acceptable (exécution < 1s). Sur un volume plus important,
un index basé sur fonction (FBI) serait justifié :

```sql
CREATE INDEX IDX_REF_NOM_NORM ON REFERENTIEL_SALLES (
    UPPER(TRIM(NOM_PLANIFICATION))
);
```

L'approche idéale serait de normaliser les noms à l'insertion (nettoyage
en amont plutôt qu'en jointure), mais les deux systèmes sources (ADE et ABYLA)
sont des logiciels éditeurs que nous ne contrôlons pas — la normalisation
ne peut se faire qu'à la lecture.

### Import CSV : choix du mode manuel

La procédure d'import (Excel → CSV → SCP → SQL*Loader) est volontairement
manuelle. Le fichier patrimoine est fourni par un service tiers 1 à 2 fois
par an, dans un format qui varie légèrement à chaque livraison (colonnes
ajoutées, valeurs nouvelles). L'intervention humaine permet de valider
le contenu avant chargement.

Pour un import plus fréquent, un script Bash avec `iconv` (encodage) +
SQL*Loader automatisé serait pertinent.

---

## Volumes

| Indicateur | Valeur |
|---|---|
| Salles dans le référentiel patrimoine | ~466 |
| Activités planifiées par an (ADE) | ~90 000 |
| Lignes d'extraction TOS (salle × événement) | ~88 000 – 108 000 |
