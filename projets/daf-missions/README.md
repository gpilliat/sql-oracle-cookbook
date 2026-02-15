# Projet DAF-MISSIONS — Reporting 360° des dépenses de missions

## Contexte

Projet de reporting budgétaire pour la Direction des Affaires Financières (DAF),
permettant l'analyse complète des dépenses de missions (déplacements professionnels).

**Démarrage :** phase POC/démo avec 10 requêtes exploratoires.
**Résultat :** 2 vues Oracle structurantes remplaçant les 10 requêtes initiales,
avec correction d'un bug d'agrégation inter-années et ajout d'un indicateur
de cohérence financière automatique.

---

## Problème résolu

### Bug d'agrégation inter-années

La requête initiale agrègeait les missions par **numéro de mission**. Or un
même numéro peut être réutilisé sur des exercices budgétaires différents →
les montants de deux missions distinctes étaient additionnés.

**Correction :** utilisation systématique de `ID_MISSION` (clé technique unique)
pour toutes les agrégations. Le couple `(NUMERO_MISSION, EXERCICE)` est exposé
uniquement en restitution pour la lecture métier.

---

## Architecture

```
┌────────────────────────────────┐
│ Schéma applicatif (R/W)       │  15+ tables métier
│                                │  (missions, trajets, transports,
│                                │   budget, indemnités, avances...)
└──────────────┬─────────────────┘
               │
               ▼
┌────────────────────────────────┐
│ Schéma lecture seule (R/O)    │  2 vues pivot
│                                │
│  VUE_MISSIONS_CUMUL            │  1 ligne = 1 mission (agrégée)
│  VUE_MISSIONS_DETAIL_TRAJETS   │  1 ligne = 1 trajet (détaillé)
└──────────────┬─────────────────┘
               │
               ▼
┌────────────────────────────────┐
│ ReportServer                   │  Export CSV/Excel pour la DAF
└────────────────────────────────┘
```

---

## Modèle de données source (15 tables)

### Table centrale

| Table | Rôle | Clé |
|---|---|---|
| MISSION | Entête : agent, dates, montants, état, payeur, exercice | ID_MISSION (PK) |

### Détail par trajet

| Table | Rôle | FK |
|---|---|---|
| TRAJET | Déplacements : dates, départ/arrivée, pays, zone | ID_MISSION |
| TRAJET_TRANSPORTS | Frais transport : montant, kms, type, perso/service | ID_TRAJET |
| TRAJET_INDEMNITES | Indemnités étranger : per diem, jours, repas, nuits | ID_TRAJET |
| TRAJET_REPAS | Repas France : montant, nombre, gratuits, admin | ID_TRAJET |
| TRAJET_NUITS | Nuitées France : montant, nombre, gratuites | ID_TRAJET |

### Niveau mission

| Table | Rôle | FK |
|---|---|---|
| BUDGET | Imputations budgétaires : EB, nature, destination | ID_MISSION |
| REMBOURSEMENTS | Remboursements divers hors trajets | ID_MISSION |
| AVANCES | Avances versées | ID_MISSION |
| DEPENSES | Dépenses engagées (DP, EJ) | ID_MISSION |
| COMMANDES | Commandes associées | ID_MISSION |
| REIMPUTATIONS | Réimputations budgétaires | ID_MISSION |

### Référentiels

TYPE_TRANSPORT, ETAT, TITRE_MISSION, PAYEUR, PAYS, ZONE_REMBOURSEMENT, MONNAIE, TYPE_REMBOURSEMENT

---

## Vue cumul (grain mission) — 11 CTE

La vue agrégée utilise **11 CTE** (Common Table Expressions) jointes sur
la table MISSION, chacune responsable d'un bloc fonctionnel :

| CTE | Rôle | Source |
|---|---|---|
| Budget_Agg | Lignes budgétaires, EB, natures, destinations | BUDGET |
| Trajets_Agg | Nombre, durée, pays, zones, itinéraires | TRAJET + PAYS + ZONE |
| Transports_Agg | Montants, kms, types, perso vs service | TRAJET_TRANSPORTS + TYPE |
| Indemnites_Etranger_Agg | Per diem, jours, repas, nuits (étranger) | TRAJET_INDEMNITES |
| Repas_Agg | Repas France : montant, gratuits, admin | TRAJET_REPAS |
| Nuits_Agg | Nuitées France : montant, gratuites | TRAJET_NUITS |
| Remboursements_Agg | Montants positifs/négatifs, types | REMBOURSEMENTS |
| Avances_Agg | Montants, validées, liquidées, dates | AVANCES |
| Depenses_Agg | DP, EJ distincts | DEPENSES |
| Commandes_Agg | Lignes de commande | COMMANDES |
| Reimputations_Agg | Réimputations validées | REIMPUTATIONS |

### Indicateur de cohérence automatique

La vue calcule un **total de frais recalculé** (somme transports +
indemnités + repas + nuits + remboursements) et le compare au montant
prévu de la mission :

```sql
CASE
    WHEN ABS(montant_prevu - total_frais_calcule) < 0.01
        THEN 'COHERENT'
    WHEN ABS(montant_prevu - total_frais_calcule) < 10
        THEN 'ECART_MINEUR'
    ELSE 'ECART_IMPORTANT'
END AS STATUT_COHERENCE
```

Cet indicateur permet à la DAF d'identifier immédiatement les missions
dont les frais détaillés ne correspondent pas au montant global.

---

## Vue détail trajets (grain trajet)

1 ligne = 1 trajet, avec le contexte mission dupliqué.

Données spécifiques par trajet :
- Numéro d'ordre dans la mission (`ROW_NUMBER()`)
- Géographie : départ, arrivée, pays, zone, étranger/DOM-TOM
- Temporalité : dates, durée en jours
- Transports : montant, kms, types, perso/service
- Indemnités étranger, repas France, nuits France
- Total frais du trajet

---

## Patterns techniques notables

### LISTAGG avec ON OVERFLOW TRUNCATE

Utilisé systématiquement pour agréger des listes (pays, types transport,
natures de dépense) sans risque de dépassement VARCHAR2 :

```sql
LISTAGG(DISTINCT p.LIBELLE, ' | ' ON OVERFLOW TRUNCATE)
    WITHIN GROUP (ORDER BY p.LIBELLE) AS PAYS_LISTE
```

### COALESCE systématique

Tous les LEFT JOIN vers les CTE utilisent `COALESCE(..., 0)` pour
garantir des zéros plutôt que des NULL dans les colonnes numériques.
Cela simplifie les formules Excel côté DAF.

### Ventilation conditionelle (CASE dans agrégat)

Utilisé pour séparer transports personnels / service, remboursements
positifs / négatifs, avances validées / liquidées :

```sql
COUNT(CASE WHEN typ.TEM_PERSONNEL = 'O'
      THEN tt.ID_TRAJET_TRANSPORT END) AS NB_TRANSPORTS_PERSO,
SUM(CASE WHEN typ.TEM_PERSONNEL = 'O'
    THEN tt.MONTANT ELSE 0 END)        AS TRANSPORTS_PERSO_MONTANT
```

---

## Historique du projet

| Date | Jalon |
|---|---|
| 30/10/2025 | Premier échange, cadrage POC |
| 07/11/2025 | 10 requêtes de démonstration livrées sur ReportServer |
| 21/11/2025 | Retour DAF : bug d'agrégation inter-années identifié |
| Fin 11/2025 | Refonte complète → 2 vues structurantes (cumul + détail) |
| 12/2025 | Validation métier DAF, passage en production |
