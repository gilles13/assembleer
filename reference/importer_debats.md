# Importer les comptes rendus des debats dans DuckDB

Lit une archive XML locale directement, un compte rendu a la fois.
Conserve une copie XML sans namespaces ainsi que les attributs complets
des points et paragraphes. Les fichiers deja importes sont ignores.

## Usage

``` r
importer_debats(
  fichier = "/tmp/assembleer-debats.xml.zip",
  cache = tools::R_user_dir("assembleer", "cache"),
  limite = Inf,
  remplacer = FALSE
)
```

## Arguments

- fichier:

  Chemin de l'archive ZIP des comptes rendus.

- cache:

  Repertoire de la base DuckDB assembleer.

- limite:

  Nombre maximal de nouveaux fichiers a traiter (Inf : tous).

- remplacer:

  Reimporter aussi les fichiers deja presents.

## Value

Tableau de suivi des fichiers traites, invisible.
