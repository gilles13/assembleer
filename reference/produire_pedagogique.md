# Produire un dossier citoyen PDF a partir des donnees parlementaires locales

Explique le parcours legislatif a partir des documents, reunions et
amendements effectivement rattaches au dossier dans la base AN. Les
donnees du Senat et DOLE ne sont pas encore importees : aucune
correspondance interchambres n'est deduite d'un titre.

## Usage

``` r
produire_pedagogique(
  uid,
  sortie = file.path("/tmp", paste0("assembleer-citoyen-", uid, ".pdf")),
  cache = tools::R_user_dir("assembleer", "cache"),
  ouvrir = TRUE,
  modele = system.file("modeles", "template.Rmd", package = "assembleer")
)
```

## Arguments

- uid:

  Identifiant officiel du dossier AN (DLR...).

- sortie:

  Chemin du PDF, dans /tmp par defaut.

- cache:

  Repertoire de la base DuckDB.

- ouvrir:

  Ouvrir le PDF produit.

- modele:

  Modele R Markdown commun du package.

## Value

Chemin du PDF, invisiblement.
