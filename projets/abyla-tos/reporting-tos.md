# Reporting — Extraction Taux d'Occupation des Salles (TOS)

## Contexte

Extraction annuelle pour le Pilotage institutionnel permettant de mesurer
l'occupation réelle des salles d'un établissement d'enseignement supérieur.

L'extraction croise les données de planification (emplois du temps) avec
le référentiel patrimonial (gestion des locaux) pour produire un indicateur
d'occupation par salle, composante et période.

---

## Grain fonctionnel

```
1 ligne = 1 salle × 1 événement planifié
```

Ce grain fin permet de calculer :
- Le taux d'occupation par salle
- L'occupation par composante / campus
- L'occupation par plage temporelle
- L'analyse par type d'usage (enseignement, réunions, colloques...)

---

## Architecture de l'extraction

```
┌──────────────────────┐
│  ADESTATS_xx         │  Données planification (ADE) — schéma annualisé
│  (Oracle)            │
│                      │
│  UHA_REPORT_01       │  Événements planifiés
│  UHA_ACTIVITIES      │  Durée, type d'activité
│  UHA_CLASSROOM       │  Salles ADE (nom, capacité ADE)
│  UHA_ACTIVITIES_     │  Lien événement ↔ salle
│    CLASSROOM         │
└──────────┬───────────┘
           │
           ├─── LEFT JOIN sur CODE_PATRIMOINE / NOM
           │
┌──────────┴───────────┐
│  REFERENTIEL_SALLES  │  Référentiel patrimoine (ABYLA)
│  (Oracle)            │  Capacité normalisée, code bâtiment
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│  Export CSV/Excel     │  Via ReportServer
│  pour le Pilotage     │  1 requête par année universitaire
└──────────────────────┘
```

---

## Colonnes de l'extraction

### Identification
- Identifiant événement, identifiant activité
- Nom de l'activité
- Type d'activité ADE (CM, TD, TP, réunion, colloque...)

### Salle
- Nom ADE de la salle
- Code patrimoine (ABYLA_ID)
- Composante (PATH1)
- **Capacité normalisée** : patrimoine si disponible, sinon fallback sur capacité ADE

### Temporalité
- Date/heure de début
- Heure de fin (calculée : début + EVENT_DURATION)
- Durée en heures

### Paramètres
- `P_Date_Debut` : borne de début (filtrable)
- `P_Date_Fin` : borne de fin (filtrable)

---

## Logique SQL (pattern)

```sql
SELECT
    -- Identification
    r.EVENT_ID,
    r.ACTIVITY_ID,
    r.ACTIVITIES_DESCRIPTION,

    -- Salle
    cl.NAME                             AS nom_salle,
    cl.PATH1                            AS composante,
    COALESCE(ref.CODE_PATRIMOINE, 
             'ID:' || cl.ID)            AS code_patrimoine,

    -- Capacité : patrimoine en priorité, sinon ADE
    COALESCE(ref.CAPACITE, cl.SIZE)     AS capacite,

    -- Temporalité
    r.ACTIVITIES_DATE_TIME              AS date_debut,
    TO_CHAR(r.ACTIVITIES_DATE_TIME 
            + (a.EVENT_DURATION / 24),
            'HH24:MI')                  AS heure_fin,
    a.EVENT_DURATION                    AS duree_heures

FROM REPORT_01 r

JOIN ACTIVITIES a
    ON a.EVENT_ID    = r.EVENT_ID
   AND a.ACTIVITY_ID = r.ACTIVITY_ID

JOIN ACTIVITIES_CLASSROOM ac
    ON ac.EVENT_ID    = r.EVENT_ID
   AND ac.ACTIVITY_ID = r.ACTIVITY_ID

JOIN CLASSROOM cl
    ON cl.ID = ac.CLASSROOM_ID

LEFT JOIN REFERENTIEL_SALLES ref
    ON UPPER(TRIM(ref.NOM_PLANIFICATION)) = UPPER(TRIM(cl.NAME))

WHERE r.ACTIVITIES_DATE_TIME BETWEEN :P_Date_Debut AND :P_Date_Fin
ORDER BY cl.PATH1, cl.NAME, r.ACTIVITIES_DATE_TIME;
```

### Points techniques

- **COALESCE sur la capacité** : le référentiel patrimoine fait autorité,
  mais en cas d'absence, on utilise la capacité ADE comme fallback
- **Schéma annualisé** : la même requête est dupliquée par année,
  seul le schéma change (ADESTATS_05, _06, _07...)
- **Heure de fin calculée** : `EVENT_DURATION` est en heures décimales
  (1.5 = 1h30), ajouté à la date de début

---

## Volumes observés

| Indicateur | Volume moyen par année |
|---|---|
| Activités planifiées (ADE) | ~90 000 |
| Activités avec salle affectée | ~82 000 |
| Lignes d'extraction (salle × événement) | ~88 000 – 108 000 |

---

## Spécifications fonctionnelles

### Le Pilotage doit pouvoir :

- Mesurer l'occupation réelle des salles sur une période
- Comparer plusieurs campus / composantes
- Identifier les salles les plus sollicitées ou sous-utilisées
- Distinguer les usages (enseignement, réunions, colloques, etc.)
- Ventiler les volumes horaires par salle, catégorie d'activité ou intervalle de dates

### Critères :

- Période filtrable (paramètres début/fin)
- Extraction **exhaustive** (enseignement + événements non académiques)
- Même logique pour toutes les années (seul le schéma change)
- Même structure, mêmes colonnes, mêmes règles d'une année à l'autre

---

## Dépendances

| Service | Responsabilité |
|---|---|
| Patrimoine (DGPI) | Mise à jour du référentiel des salles (capacités, codes) |
| DSI (DNUM) | Mise à jour annuelle de la requête dans ReportServer |
| Pilotage | Validation de la période et de la cohérence des volumes |

---

## Livrables

- 1 requête ReportServer par année universitaire
- Export CSV/Excel pour exploitation Pilotage
- Mise à jour annuelle dans le même dossier ReportServer

---

## Voir aussi

- [Migration schéma + import CSV](migration-schema.md)
- [Contrôle qualité croisé ADE ↔ ABYLA](controle-qualite.md)
