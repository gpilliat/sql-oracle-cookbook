# Projet ABYLA-TOS — Référentiel des salles et taux d'occupation

## Contexte

Projet complet couvrant toute la chaîne : de l'import du référentiel patrimonial
des salles jusqu'au reporting du taux d'occupation pour le Pilotage institutionnel.

**Ce que j'ai fait :**
- Évolution du schéma Oracle (8 → 12 colonnes) pour intégrer les nouvelles données patrimoine
- Procédure d'import CSV régulier depuis les fichiers Excel du service patrimoine
- Requêtes de reporting croisant planification (ADE) et patrimoine (ABYLA)
- Contrôle qualité automatisé pour détecter les incohérences entre les deux référentiels

---

## Architecture du projet

```
Fichier Excel (patrimoine)
        │
        ▼
┌──────────────────────┐
│ 1. IMPORT CSV        │  Évolution DDL + chargement régulier
│    → Oracle          │  (ce dossier : migration-schema.md)
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
              │    → ReportServer│  (ce dossier : reporting-tos.md)
              └──────────┬───────┘
                         │
                         ▼
              ┌──────────────────┐
              │ 3. CONTRÔLE      │  Détection des salles
              │    QUALITÉ       │  non référencées
              │                  │  (ce dossier : controle-qualite.md)
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

## Volumes

| Indicateur | Valeur |
|---|---|
| Salles dans le référentiel patrimoine | ~466 |
| Activités planifiées par an (ADE) | ~90 000 |
| Lignes d'extraction TOS (salle × événement) | ~88 000 – 108 000 |
