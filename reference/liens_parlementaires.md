# Retrouver les liens parlementaires formels d'un objet

Les rapprochements par titre, sujet ou similarite sont exclus. Seules
les correspondances exactes entre identifiants stockes sont rendues.

## Usage

``` r
liens_parlementaires(
  type = c("dossier", "amendement", "texte", "scrutin"),
  uid = NULL,
  cache = tools::R_user_dir("assembleer", "cache")
)
```

## Arguments

- type:

  Type de l'objet : dossier, amendement, texte ou scrutin.

- uid:

  Identifiant officiel de l'objet. Si NULL, utilise le premier
  identifiant local disponible.

- cache:

  Repertoire de la base locale DuckDB.

## Value

Un data.frame : source_type, source_uid, relation, cible_type,
cible_uid, preuve_champ, preuve_valeur.
