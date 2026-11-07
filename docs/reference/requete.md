# Executer une requete SQL sur les donnees locales

Executer une requete SQL sur les donnees locales

## Usage

``` r
requete(sql, params = list(), cache = tools::R_user_dir("assembleer", "cache"))
```

## Arguments

- sql:

  Requete SQL DuckDB (lecture seule).

- params:

  Parametres SQL pour les marqueurs \`?\`.

- cache:

  Repertoire local de la base.

## Value

Un data.frame.
