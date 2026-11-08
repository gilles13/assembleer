# Actualiser explicitement la base locale

Actualiser explicitement la base locale

## Usage

``` r
actualiser(
  sources = c("deputes", "amo40", "amo20", "scrutins", "dossiers", "amendements",
    "reunions"),
  jours = 1,
  forcer = FALSE,
  reimporter = FALSE,
  cache = tools::R_user_dir("assembleer", "cache"),
  verbose = TRUE
)
```

## Arguments

- sources:

  Sources a verifier.

- jours:

  Delai minimal entre deux verifications, en jours.

- forcer:

  Ignorer le delai de verification.

- reimporter:

  Reimporter les archives, meme inchangees (migration des effectifs).

- cache:

  Repertoire local.

- verbose:

  Afficher les etapes de verification et d'importation.

## Value

Tableau de suivi : verification, telechargement, changement, fichiers
traites, lignes importees et volume telecharge (octets).
