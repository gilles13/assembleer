# Produire la cheatsheet HTML

Génère une page HTML autonome sur le modèle de la cheatsheet eduschool.

## Usage

``` r
produire_cheatsheet(
  fichier = file.path(tempdir(), "assembleer-cheatsheet.html"),
  ouvrir = TRUE
)
```

## Arguments

- fichier:

  Chemin du fichier HTML à produire.

- ouvrir:

  Ouvrir le fichier dans le navigateur après génération.

## Value

Chemin du fichier HTML, invisiblement.
