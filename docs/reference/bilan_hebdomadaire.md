# Bilan hebdomadaire des scrutins publics

Regroupe les scrutins par dossier legislatif a partir des archives JSON
deja presentes dans le cache. Aucun acces reseau ni modification de la
base. Les adoptions/rejets comptent des scrutins, pas des textes de loi.

## Usage

``` r
bilan_hebdomadaire(semaine, cache = tools::R_user_dir("assembleer", "cache"))
```

## Arguments

- semaine:

  Premier jour de la semaine (lundi).

- cache:

  Repertoire du cache assembleer.

## Value

Liste de deux data.frames : dossiers (synthese) et scrutins (detail).
