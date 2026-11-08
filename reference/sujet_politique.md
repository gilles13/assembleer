# Rechercher les documents relatifs a un sujet politique

Une correspondance textuelle n'est pas un lien parlementaire officiel.
Chaque resultat conserve son identifiant et sa source documentaire.

## Usage

``` r
sujet_politique(
  texte,
  limite = 100L,
  cache = tools::R_user_dir("assembleer", "cache")
)
```

## Arguments

- texte:

  Expression recherchee dans les titres des documents.

- limite:

  Nombre maximal de resultats par categorie.

- cache:

  Repertoire de la base DuckDB.

## Value

Liste de quatre data.frames : debats, textes, amendements, votes.
