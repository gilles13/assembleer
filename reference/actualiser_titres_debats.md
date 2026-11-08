# Completer les titres des points deja importes

Extrait les titres directement des XML conserves dans debats_seances. Ne
telecharge rien et ne reimporte pas les archives ZIP.

## Usage

``` r
actualiser_titres_debats(cache = tools::R_user_dir("assembleer", "cache"))
```

## Arguments

- cache:

  Repertoire de la base DuckDB assembleer.

## Value

Nombre de points avec un titre non vide, invisible.
