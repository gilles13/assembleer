# Liste PDF detaillee des deputes par groupe parlementaire

Produit une fiche a partir des colonnes disponibles dans le CSV officiel
: identifiant, prenom, nom, region, departement, circonscription et
profession. Un sigle de groupe peut etre fourni pour limiter la liste.

## Usage

``` r
fiche_deputes_groupes(
  formation = NULL,
  fichier = file.path(tempdir(), "assembleer-deputes-groupes.pdf"),
  cache = tools::R_user_dir("assembleer", "cache"),
  ouvrir = TRUE
)
```

## Arguments

- formation:

  Sigle du groupe (par exemple "RN"), ou NULL pour tous.

- fichier:

  Chemin du PDF a produire.

- cache:

  Repertoire local de la base.

- ouvrir:

  Ouvrir automatiquement le PDF.

## Value

Chemin du PDF, invisiblement.
