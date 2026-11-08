# Rechercher les questions ecrites de l'Assemblee nationale

Recherche locale dans les questions de la XVIIe legislature deja
importees dans DuckDB. Les textes integraux sont conserves dans le
resultat.

## Usage

``` r
rechercher_questions(
  mots = NULL,
  rubrique = NULL,
  groupe = NULL,
  ministere = NULL,
  date_debut = NULL,
  date_fin = NULL,
  dans = c("question", "reponse", "tout"),
  limite = NULL,
  cache = tools::R_user_dir("assembleer", "cache")
)
```

## Arguments

- mots:

  Un ou plusieurs mots ou expressions, tous requis (ET).

- rubrique, groupe, ministere:

  Filtres textuels facultatifs (sous-chaines, sans distinction de
  casse).

- date_debut, date_fin:

  Dates de publication de la question (incluses).

- dans:

  Chercher dans la question, la reponse, ou les deux.

- limite:

  Nombre maximal de resultats ; \`NULL\` pour tous.

- cache:

  Repertoire local de la base.

## Value

Un data.frame avec identifiant, metadonnees et textes integraux.
