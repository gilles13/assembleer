# Importer la base DOSLEG du Senat dans DuckDB

Charge integralement les 53 tables du dump PostgreSQL officiel dans le
schema \`senat\`. Toutes les colonnes sont conservees en VARCHAR afin de
preserver sans perte les codes, dates et valeurs du dump d'origine.
L'archive reste dans le cache. Le schema est remplace atomiquement.

## Usage

``` r
importer_dosleg(
  cache = tools::R_user_dir("assembleer", "cache"),
  archive = file.path(cache, "dosleg.zip"),
  reimporter = FALSE,
  taille_lot = 2000L
)
```

## Arguments

- cache:

  Repertoire de stockage d'assembleer.

- archive:

  Archive ZIP locale ; telechargee si absente.

- reimporter:

  Forcer le rechargement d'une archive deja importee.

- taille_lot:

  Nombre de lignes par lot.

## Value

Tableau des effectifs par table, invisiblement.
