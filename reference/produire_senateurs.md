# Produire un annuaire PDF des senateurs

Lit exclusivement la table locale \`senateurs.sen\` issue du dump
officiel du Senat. Le PDF utilise le modele commun \`template.Rmd\`
(sans fancyhdr).

## Usage

``` r
produire_senateurs(
  type = c("actif", "anciens", "autres", "tous"),
  sortie = file.path("/tmp", paste0("assembleer-senateurs-", match.arg(type), ".pdf")),
  cache = tools::R_user_dir("assembleer", "cache"),
  ouvrir = TRUE,
  modele = system.file("modeles", "template.Rmd", package = "assembleer")
)
```

## Arguments

- type:

  Statut a retenir : actif, anciens, autres ou tous.

- sortie:

  Chemin du PDF produit, dans /tmp par defaut.

- cache:

  Repertoire du cache assembleer.

- ouvrir:

  Ouvrir le PDF apres generation.

- modele:

  Modele PDF commun.

## Value

Chemin du PDF, invisiblement.
