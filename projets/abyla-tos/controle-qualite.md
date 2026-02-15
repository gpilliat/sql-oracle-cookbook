# Pattern : Contrôle qualité croisé entre deux référentiels

## Problème

Comment détecter les enregistrements d'un système A (planification) qui
n'ont pas de correspondance dans un système B (patrimoine), afin de
fiabiliser le reporting ?

---

## Cas concret : salles de planification sans référence patrimoine

Le système de planification (emplois du temps) gère des salles avec
ses propres identifiants. Le système patrimonial (gestion des locaux)
gère les mêmes salles avec d'autres identifiants et des données
complémentaires (capacité, surface, code bâtiment).

Le reporting a besoin des deux : les événements planifiés ET les
données patrimoniales. Les salles non référencées dans le patrimoine
créent des trous dans les rapports.

---

## Logique de détection

### Étape 1 : identifier les salles réellement utilisées

Ne pas traiter toutes les salles du référentiel, mais uniquement celles
qui apparaissent dans des événements planifiés sur la période étudiée.

```sql
-- Événements réellement planifiés sur la période
SELECT DISTINCT r.EVENT_ID, r.ACTIVITY_ID
FROM REPORT_01 r
WHERE r.ACTIVITIES_DATE_TIME BETWEEN :date_debut AND :date_fin;
```

### Étape 2 : rattacher les salles affectées

```sql
-- Salles associées à ces événements
SELECT DISTINCT
    c.ID          AS salle_id,
    c.NAME        AS nom_salle,
    c.PATH1       AS composante,
    c.ABYLA_ID    AS code_patrimoine
FROM ACTIVITIES_CLASSROOM ac
JOIN CLASSROOM c ON c.ID = ac.CLASSROOM_ID
WHERE (ac.EVENT_ID, ac.ACTIVITY_ID) IN (
    -- sous-requête des événements de la période
);
```

### Étape 3 : détecter les absences

```sql
-- Salles sans correspondance patrimoine
SELECT
    c.PATH1       AS composante,
    c.ID          AS salle_id,
    c.NAME        AS nom_planification,
    c.ABYLA_ID    AS code_patrimoine,
    COUNT(*)      AS nb_affectations
FROM salles_utilisees c
LEFT JOIN REFERENTIEL_SALLES ref
    ON ref.CODE_PATRIMOINE = c.ABYLA_ID
    OR UPPER(TRIM(ref.NOM_PLANIFICATION)) = UPPER(TRIM(c.NAME))
WHERE ref.CODE_PATRIMOINE IS NULL
GROUP BY c.PATH1, c.ID, c.NAME, c.ABYLA_ID
ORDER BY nb_affectations DESC, composante, nom_planification;
```

**Double tentative de correspondance :**
- Par identifiant (CODE_PATRIMOINE)
- Par nom (en dernier recours, après normalisation)

Une salle est considérée "manquante" uniquement si les deux méthodes échouent.

---

## Résultat attendu

Une liste **courte et priorisée** des salles non référencées,
triée par nombre d'utilisations (les plus utilisées en premier) :

| Composante | Salle | Nom planification | Code patrimoine | Nb affectations |
|---|---|---|---|---|
| COMP_A | 1234 | Amphi 200 | (vide) | 847 |
| COMP_B | 5678 | Salle TP Chimie | (vide) | 412 |
| ... | | | | |

---

## Points de vigilance

- **Salles temporaires** : les événements ponctuels (examens, réservations
  exceptionnelles) peuvent faire apparaître des salles "fantômes" →
  à valider manuellement
- **Variations orthographiques** : différences de casse, accents, espaces
  entre les deux systèmes → normaliser avec `UPPER(TRIM(...))` minimum
- **Salles sans code patrimoine** : si le champ `ABYLA_ID` est vide
  dans le système de planification, la correspondance par ID est
  impossible → la correspondance par nom prend le relais

---

## Utilisation

Ce contrôle est destiné à être fourni au service patrimoine pour :
- Intégrer les salles manquantes dans le référentiel
- Corriger les correspondances existantes (orthographe, codes)
- Fiabiliser les rapports d'occupation et de coûts de formation
