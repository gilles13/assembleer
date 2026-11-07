# Produire un bilan hebdomadaire PDF

Produit un PDF a partir du bilan local des scrutins publics. Aucun acces
reseau. Les resultats portent sur les scrutins, pas sur l'adoption
definitive des lois.

## Usage

``` r
produire_bilan(semaine,
  fichier = file.path(tempdir(), paste0("assembleer-bilan-",
    as.Date(semaine), ".pdf")),
  cache = tools::R_user_dir("assembleer", "cache"),
  ouvrir = TRUE)
```

## Arguments

- semaine:

  Lundi de la semaine a presenter.

- fichier:

  Chemin du PDF genere.

- cache:

  Repertoire du cache assembleer.

- ouvrir:

  Ouvrir le PDF apres generation.

## Value

Chemin du PDF, invisiblement.
