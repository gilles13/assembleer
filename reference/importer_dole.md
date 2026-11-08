# Importer le corpus complet DOLE de la DILA

Recupere le stock global officiel et applique toutes les mises a jour
posterieures dans l'ordre chronologique. Les XML originaux sont
conserves dans DuckDB, ainsi que tous leurs liens documentaires. Les
archives sont conservees dans le cache et les mises a jour deja
importees sont ignorees.

## Usage

``` r
importer_dole(
  cache = tools::R_user_dir("assembleer", "cache"),
  archives = NULL,
  reimporter = FALSE,
  verbose = TRUE,
  progression = 500L
)
```

## Arguments

- cache:

  Repertoire de stockage assembleer.

- archives:

  Noms d'archives a traiter ; NULL pour le catalogue officiel complet
  (stock global et mises a jour).

- reimporter:

  Reconstituer le schema DOLE depuis le stock global.

- verbose:

  Afficher les etapes et la progression (TRUE par defaut).

- progression:

  Frequence des messages de progression, en fichiers XML.

## Value

Effectifs des archives traitees, invisiblement.
