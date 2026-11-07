# assembleer

![Logo assembleer](reference/figures/logo_hexa.png)

Accéder aux données ouvertes de l’Assemblée nationale depuis R, avec un
stockage local DuckDB.

## Installation

``` r

install.packages("remotes")
remotes::install_github("gilles13/assembleer")
```

## Démarrer

``` r

assembleer::actualiser()  # télécharge ou vérifie les sources officielles
assembleer::chercher_scrutins("finance", limite = 10)
assembleer::bilan_votes(par = "groupe")
```

Les lectures sont locales : elles ne déclenchent pas de téléchargement.
