# Produire le PDF des echanges d'un point de debat

Inclut le point selectionne et tous ses sous-points, sans modifier
l'ordre des paragraphes ni regrouper les interventions.

## Usage

``` r
produire_debat(
  fichier = "xml/compteRendu/CRSANR5L17S2025E1N001.xml",
  id_syceron = "3827580",
  sortie = file.path("/tmp", paste0("assembleer-debat-", id_syceron, ".pdf")),
  cache = tools::R_user_dir("assembleer", "cache"),
  ouvrir = FALSE,
  modele = system.file("modeles", "template.Rmd", package = "assembleer")
)
```

## Arguments

- fichier:

  Chemin du compte rendu dans l'archive XML importee.

- id_syceron:

  Identifiant du point de debat.

- sortie:

  Chemin du PDF a produire, dans /tmp par defaut.

- cache:

  Repertoire de la base DuckDB assembleer.

- ouvrir:

  Ouvrir le PDF apres generation.

- modele:

  Fichier Rmd du modele, par defaut celui du package. La date de la
  seance provient des reunions officielles deja importees.

## Value

Chemin du PDF, invisiblement.
