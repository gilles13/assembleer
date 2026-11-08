# Produire une fiche PDF d'un dossier legislatif local

Les documents sont relies par leur identifiant officiel de dossier.
Aucun rapprochement thematique et aucun telechargement ne sont
effectues.

## Usage

``` r
produire_dossier(
  uid,
  sortie = file.path("/tmp", paste0("assembleer-dossier-", uid, ".pdf")),
  cache = tools::R_user_dir("assembleer", "cache"),
  ouvrir = FALSE,
  modele = system.file("modeles", "template.Rmd", package = "assembleer")
)
```

## Arguments

- uid:

  Identifiant officiel du dossier legislatif.

- sortie:

  Chemin du PDF, dans /tmp par defaut.

- cache:

  Repertoire de la base DuckDB.

- ouvrir:

  Ouvrir le PDF apres production.

- modele:

  Modele R Markdown du package.

## Value

Chemin du PDF, invisiblement.
