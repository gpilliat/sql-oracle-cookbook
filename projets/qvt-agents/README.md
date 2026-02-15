# Projet QVT — Liste des agents permanents pour la gestion des accès

## Contexte

Création d'une vue SQL dédiée pour la Qualité de Vie au Travail (QVT),
permettant de gérer les droits d'accès à un service interne (billetterie).

La vue produit chaque jour une photo des agents (actifs et sortis) avec
leurs dates d'entrée et de sortie, pour identifier :
- les agents qui conservent leur accès
- ceux dont l'accès doit être retiré
- les situations nécessitant vérification par la DRH

**Règle métier fondamentale :** un agent avec `DATE_SORTIE` non nulle doit être désactivé.

---

## Problème résolu

La vue historique existante (`LISTE_DONNEES_AGENTS`) présentait :
- Périmètre ambigu (hébergés inclus à tort)
- Dates d'entrée/sortie incomplètes ou incohérentes
- Doublons non maîtrisés
- Impossibilité d'exclure correctement les agents hébergés

→ Création d'une **vue spécifique** avec des règles métier validées par la DRH.

---

## Architecture (9 CTE)

```
┌─────────────────────────────────────────────────────────────┐
│                    Vue V_AGENTS_QVT                          │
│                                                              │
│  CTE 1: lda ──────── Identité + dédoublonnage (ROW_NUMBER) │
│  CTE 2: ids ──────── Correspondance ID interne              │
│  CTE 3: mail ─────── Email unique sécurisé                  │
│  CTE 4: contrat_av ─ Fin effective par avenant               │
│  CTE 5: cc ────────── Contrat principal (actif prioritaire)  │
│  CTE 6: fp ────────── Première position (date d'entrée)     │
│  CTE 7: lp ────────── Dernière fin de position (sortie)     │
│  CTE 8: ap ────────── Positions actives aujourd'hui          │
│  CTE 9: heberges ─── Hébergés actifs (à exclure)            │
│                                                              │
│  → base ─── Assemblage + calcul D_ENTREE / D_SORTIE         │
│  → SELECT FINAL ─── 1 ligne/agent, 10 colonnes, filtré      │
└─────────────────────────────────────────────────────────────┘
```

---

## Sources de données (3 schémas)

| Schéma | Tables | Données |
|---|---|---|
| OPENREAD | LISTE_DONNEES_AGENTS | Identité, civilité, affectation, corps |
| GRHUM | INDIVIDU, COMPTE, COMPTE_EMAIL | Correspondance ID, email |
| MANGUE | CONTRAT, CONTRAT_AVENANT, CHANGEMENT_POSITION, CONTRAT_HEBERGES | Contrats, avenants, positions, hébergés |

---

## Règles métier (validées DRH)

### Date d'entrée

Première entrée administrative réelle, par ordre de priorité :
1. Première position validée (titulaire)
2. Premier contrat
3. Première position historique

### Date de sortie

- Position active → `DATE_SORTIE = NULL`
- Plus de position active → `DATE_SORTIE = COALESCE(fin_contrat_effective, dernière_fin_position)`

Cas confirmés comme "sortie" :
- Disponibilité sortante, détachement sortant, retraite

### Fins anticipées (avenants)

La date de fin d'un avenant **remplace** la date de fin théorique du contrat.

**Bug corrigé (v1.1) :** `MAX(D_FIN_CONTRAT_AV)` ignorait les avenants avec
fin NULL (prolongation indéfinie). Corrigé par sélection de l'avenant le plus
récent via `ROW_NUMBER() ORDER BY D_DEB DESC, ORDRE DESC`.

### Exclusions

Tous les agents présents dans `CONTRAT_HEBERGES` avec période active
sont exclus (y compris les professeurs émérites hébergés).

### Dédoublonnage

`ROW_NUMBER()` uniquement — jamais `DISTINCT` (qui masque les incohérences).

---

## Sortie (10 colonnes)

| Colonne | Description |
|---|---|
| GENTIME | Horodatage de génération |
| CIV | Civilité |
| NOM | Nom d'usage |
| PRENOM | Prénom |
| NOM_PATR | Nom patronymique |
| AFFECTATION | Service / composante |
| CORPS | Corps administratif |
| DATE_ENTREE | Date d'entrée (texte DD/MM/YYYY) |
| DATE_SORTIE | Date de sortie (vide si actif) |
| EMAIL | Email institutionnel |

---

## Patterns techniques notables

### Normalisation des accents pour les positions

```sql
UPPER(TRANSLATE(
    L.POSITION,
    'ÀÂÄÉÈÊËÎÏÔÖÙÛÜYàâäéèêëîïôöùûüÿÇç',
    'AAAEEEEIIOOUUUYAAAEEEEIIOOUUUYCc'
)) AS POSITION_NORM
```

### Email sécurisé (ajout de domaine si absent)

```sql
CASE
    WHEN INSTR(email, '@') = 0
        THEN LOWER(email) || '@uha.fr'
    ELSE LOWER(email)
END AS EMAIL
```

### Contrat principal avec priorité à l'actif

```sql
ROW_NUMBER() OVER (
    PARTITION BY NO_DOSSIER_PERS
    ORDER BY
        CASE WHEN contrat_actif_aujourd_hui THEN 0 ELSE 1 END,
        date_debut_contrat DESC
) AS rn
-- rn = 1 → contrat prioritaire
```

### Tri alphabétique français

```sql
ORDER BY
    NLSSORT(NOM, 'NLS_SORT=FRENCH_M'),
    NLSSORT(PRENOM, 'NLS_SORT=FRENCH_M')
```

---

## Exigences qualité

| Critère | Exigence |
|---|---|
| Univoque | 1 ligne par agent |
| Stable | Même entrée RH → même résultat |
| Précise | Dates correctement calculées |
| Exploitable | Filtrage et export ReportServer |
| Robuste | Indépendante des vues historiques |

---

## Chronologie

| Date | Jalon |
|---|---|
| 12/2024 | Création initiale (v1.0) |
| 12/2025 | Correction bug DATE_SORTIE — fins anticipées (v1.1) |
