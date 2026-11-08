# Produire les syntheses statistiques des senateurs en PDF

Une page par theme, a partir de la base DuckDB locale. Les groupes sont
presentes sous leur nom complet suivi du sigle lorsqu'il est connu.

## Usage

``` r
senateurs_synthese(
  type = c("actif", "anciens", "autres", "tous"),
  groupe = NULL,
  syntheses = c("groupes", "sexe", "ages", "professions", "territoires", "commissions"),
  sortie = file.path("/tmp", paste0("assembleer-senateurs-synthese-", match.arg(type),
    ".pdf")),
  cache = tools::R_user_dir("assembleer", "cache"),
  ouvrir = TRUE,
  modele = system.file("modeles", "template.Rmd", package = "assembleer")
)
```

## Arguments

- type:

  Population : actif, anciens, autres ou tous.

- groupe:

  Code ou libelle de groupe a retenir, ou NULL pour tous.

- syntheses:

  Themes a produire : groupes, sexe, ages, professions, territoires,
  commissions.

- sortie:

  Chemin du PDF, dans /tmp par defaut.

- cache:

  Repertoire du cache assembleer.

- ouvrir:

  Ouvrir le document apres production.

- modele:

  Modele PDF commun.

## Value

Chemin du PDF, invisiblement.
