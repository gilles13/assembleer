# Rechercher les sujets des debats parlementaires

Retourne les identifiants necessaires a produire_debat(). La nature est
derivee des codes officiels, sans classification thematique
artificielle.

## Usage

``` r
catalogue_debats(
  texte = NULL,
  nature = NULL,
  fichier = NULL,
  limite = 100L,
  cache = tools::R_user_dir("assembleer", "cache")
)
```

## Arguments

- texte:

  Recherche insensible a la casse dans le titre officiel.

- nature:

  Une ou plusieurs natures : question_gouvernement, question_orale,
  texte_legislatif, sous_partie, discussion_generale,
  discussion_articles, autre.

- fichier:

  Restreindre a une seance (chemin XML interne).

- limite:

  Nombre maximal de resultats.

- cache:

  Repertoire de la base DuckDB.

## Value

data.frame des points, titres et natures.
