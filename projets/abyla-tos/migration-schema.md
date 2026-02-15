# Import et évolution du référentiel des salles

## Contexte

Le référentiel des salles est fourni par le service patrimoine sous forme
de fichier Excel. Il fait le lien entre les salles du système de planification
(ADE) et le système de gestion patrimoniale (ABYLA).

---

## Évolution du schéma (DDL)

### Avant (8 colonnes, aucune contrainte)

```sql
CREATE TABLE REFERENTIEL_SALLES (
    COMPOSANTE_ID     VARCHAR2(32),
    ETAGE             VARCHAR2(32),
    NOM_PATRIMOINE    VARCHAR2(50),
    NOM_PLANIFICATION VARCHAR2(50),
    CODE_PATRIMOINE   VARCHAR2(16),
    CAPACITE          NUMBER(4,0),
    CAPACITE_EXAM     NUMBER(4,0),
    TAG_ACTIF         VARCHAR2(3)
);
```

### Après (12 colonnes, contraintes, tailles ajustées)

```sql
CREATE TABLE REFERENTIEL_SALLES (
    COMPOSANTE_ID      VARCHAR2(10)  NOT NULL,
    ETAGE              VARCHAR2(50),
    NOM_PATRIMOINE     VARCHAR2(50)  NOT NULL,
    NOM_PLANIFICATION  VARCHAR2(100),
    CODE_PATRIMOINE    VARCHAR2(16),
    CAPACITE           NUMBER(4,0),
    CAPACITE_EXAM      NUMBER(4,0),
    TAG_ACTIF          VARCHAR2(10)  DEFAULT 'oui' NOT NULL,
    PROJET_GRAPHIQUE   VARCHAR2(50),     -- type d'usage
    ZONE_FONCTIONNELLE VARCHAR2(50),     -- typologie (SEN, REU, BUR...)
    TYPE_PIECE         VARCHAR2(50),
    SURFACE_PIECE      NUMBER(6,2)       -- surface en m²
);
```

### Décisions de dimensionnement

| Colonne | Avant | Après | Justification |
|---|---|---|---|
| COMPOSANTE_ID | VARCHAR2(32) | VARCHAR2(10) | Valeurs courtes (codes 4-5 car.) |
| ETAGE | VARCHAR2(32) | VARCHAR2(50) | Valeurs longues ("REZ DE CHAUSSEE") |
| NOM_PLANIFICATION | VARCHAR2(50) | VARCHAR2(100) | Descriptions complètes |
| TAG_ACTIF | VARCHAR2(3) | VARCHAR2(10) | Valeurs composites ("oui CODE_X") |

### Script de migration

```sql
-- Ajout des colonnes
ALTER TABLE REFERENTIEL_SALLES ADD (
    PROJET_GRAPHIQUE   VARCHAR2(50),
    ZONE_FONCTIONNELLE VARCHAR2(50),
    TYPE_PIECE         VARCHAR2(50),
    SURFACE_PIECE      NUMBER(6,2)
);

-- Modification des tailles
ALTER TABLE REFERENTIEL_SALLES MODIFY COMPOSANTE_ID     VARCHAR2(10);
ALTER TABLE REFERENTIEL_SALLES MODIFY ETAGE             VARCHAR2(50);
ALTER TABLE REFERENTIEL_SALLES MODIFY NOM_PLANIFICATION VARCHAR2(100);
ALTER TABLE REFERENTIEL_SALLES MODIFY TAG_ACTIF         VARCHAR2(10);

-- Contraintes
ALTER TABLE REFERENTIEL_SALLES MODIFY COMPOSANTE_ID NOT NULL;
ALTER TABLE REFERENTIEL_SALLES MODIFY NOM_PATRIMOINE NOT NULL;
ALTER TABLE REFERENTIEL_SALLES MODIFY TAG_ACTIF DEFAULT 'oui' NOT NULL;
```

---

## Procédure d'import CSV

### 1. Préparer le fichier Excel

1. Ouvrir le fichier source (patrimoine)
2. Vérifier l'ordre des 12 colonnes
3. Supprimer les lignes vides
4. Enregistrer sous → **CSV UTF-8** (séparateur : point-virgule)

### 2. Transférer vers le serveur

```bash
scp fichier.csv oracle@serveur:/tmp/referentiel_salles_YYYY-MM.csv
```

### 3. Importer

Import via SQL*Loader ou table externe Oracle, `CHARACTERSET AL32UTF8`.

---

## Pièges identifiés

**Fausse clé primaire :** `COMPOSANTE_ID` n'est pas un identifiant unique
mais un code composante. La vraie clé est `CODE_PATRIMOINE` (466 uniques / 466 lignes).
Les "doublons" sur le nom de salle sont normaux (salle "101" dans plusieurs bâtiments).

**Mot réservé Oracle :** `ZONE` est un mot réservé → renommé en `ZONE_FONCTIONNELLE`.

**Encodage :** toujours UTF-8. SQL*Loader : `CHARACTERSET AL32UTF8`.

---

## Vérification post-import

```sql
-- Unicité du code patrimoine
SELECT CODE_PATRIMOINE, COUNT(*)
FROM REFERENTIEL_SALLES
GROUP BY CODE_PATRIMOINE
HAVING COUNT(*) > 1;
-- Attendu : aucune ligne

-- Contraintes NOT NULL
SELECT COUNT(*)
FROM REFERENTIEL_SALLES
WHERE COMPOSANTE_ID IS NULL
   OR NOM_PATRIMOINE IS NULL
   OR TAG_ACTIF IS NULL;
-- Attendu : 0
```
