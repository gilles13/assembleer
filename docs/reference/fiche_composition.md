# Fiche PDF de composition de l'Assemblee

Produit un document sobre a partir de la table locale des deputes. La
colonne de groupe doit etre presente dans le CSV officiel importe. Aucun
acces reseau n'est effectue.

## Usage

``` r
fiche_composition(
  fichier = file.path(tempdir(), "assembleer-composition.pdf"),
  cache = tools::R_user_dir("assembleer", "cache"),
  ouvrir = TRUE
)
```

## Arguments

- fichier:

  Chemin du PDF a produire.

- cache:

  Repertoire local de la base.

- ouvrir:

  Ouvrir le PDF apres generation (Linux avec xdg-open).

## Value

Chemin du PDF, invisiblement.
