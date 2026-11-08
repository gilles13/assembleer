# Produire un inventaire documentaire officiel d'un dossier DOLE

Construit un PDF a partir des liens explicites contenus dans DOLE.
Aucune jointure par titre ni date deduite des libelles.

## Usage

``` r
produire_documentation(
  uid = "JORFDOLE000054148224",
  sortie = file.path("/tmp", paste0("assembleer-documentation-", uid, ".pdf")),
  cache = tools::R_user_dir("assembleer", "cache"),
  ouvrir = TRUE,
  modele = system.file("modeles", "template.Rmd", package = "assembleer")
)
```

## Arguments

- uid:

  Identifiant DOLE (JORFDOLE...).

- sortie:

  Chemin du PDF dans /tmp par defaut.

- cache:

  Cache local assembleer.

- ouvrir:

  Ouvrir le PDF apres generation.

- modele:

  Modele PDF commun du package.

## Value

Chemin du PDF, invisiblement.
