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

## Sources officielles

Un [inventaire initial des sources de l’Assemblée
nationale](https://data.assemblee-nationale.fr/) est livré avec le
package (`inst/extdata/sources_an.csv`). Il recense les jeux logiques,
leur granularité et les vérifications à mener avant importation. Ce
catalogue de travail, distinct des tables DuckDB, n’est pas encore
exhaustif et ne remplace pas les ressources officielles.

``` r

sources = read.csv(
  system.file("extdata", "sources_an.csv", package = "assembleer"),
  sep = ";", fileEncoding = "UTF-8", check.names = FALSE
)
```

## Documentation des correspondances parlementaires

La vignette [Comprendre les données de l’Assemblée
nationale](https://gilles13.github.io/assembleer/vignettes/comprendre-donnees.Rmd)
présente les rapprochements exploratoires entre dossiers AN, DOLE (DILA)
et dossiers du Sénat, les chiffres de couverture des références et les
relations encore à vérifier. Les catalogues `sources_an.csv`,
`sources_senat.csv` et `sources_divers.csv` sont des inventaires de
sources, pas des tables DuckDB importées.

## Dossier citoyen PDF

Le package produit un document pedagogique a partir des relations
officielles de la base locale (dossier, textes, reunions et
amendements), sans inferer de liens entre les deux chambres par simple
ressemblance des titres.

``` r

produire_pedagogique("DLR5L17N52767", ouvrir = TRUE)
```

Les references senatoriales presentes dans les dossiers AN sont
signalees, mais les corpus DOLE et DOSLEG ne sont pas encore integres.
