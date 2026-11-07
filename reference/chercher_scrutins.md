# Rechercher des scrutins

Rechercher des scrutins

## Usage

``` r
chercher_scrutins(
  texte = NULL,
  depuis = NULL,
  avant = NULL,
  limite = 100L,
  cache = tools::R_user_dir("assembleer", "cache")
)
```

## Arguments

- texte:

  Expression recherchee dans le titre (sans tenir compte de la casse).

- depuis, avant:

  Bornes inclusives de date, facultatives.

- limite:

  Nombre maximal de scrutins retournes.

- cache:

  Repertoire local de la base.

## Value

Un data.frame, trie par date et numero decroissants.
