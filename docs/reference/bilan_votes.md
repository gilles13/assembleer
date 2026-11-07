# Bilan des votes par groupe ou par depute

Bilan des votes par groupe ou par depute

## Usage

``` r
bilan_votes(
  par = c("groupe", "depute"),
  depuis = NULL,
  avant = NULL,
  cache = tools::R_user_dir("assembleer", "cache")
)
```

## Arguments

- par:

  Niveau de regroupement : groupe ou depute.

- depuis, avant:

  Bornes de date inclusives, facultatives.

- cache:

  Repertoire local de la base.

## Value

Nombre de votes pour, contre, abstentions et non-votants.
