# Lire une table locale DuckDB

Lire une table locale DuckDB

## Usage

``` r
lire_table(
  table = c("deputes", "acteurs", "organes", "scrutins", "votes",
    "effectifs_groupes_scrutins", "dossiers_legislatifs", "amendements"),
  cache = tools::R_user_dir("assembleer", "cache")
)
```

## Arguments

- table:

  Table disponible dans la base.

- cache:

  Repertoire de stockage local.

## Value

Un data.frame.
