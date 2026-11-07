# Fiche PDF d'une motion de censure

Seuls les votes favorables sont recenses. Les effectifs actuels des
groupes ne sont pas des effectifs historiques : ils ne sont jamais
utilises par defaut.

## Usage

``` r
fiche_motion_censure(
  numero,
  seuil = 289L,
  fichier = NULL,
  format = c("auto", "pdf", "html"),
  cache = tools::R_user_dir("assembleer", "cache"),
  ouvrir = TRUE
)
```

## Arguments

- numero:

  Numero du scrutin ou UID.

- seuil:

  Majorite absolue des membres composant l'Assemblee a cette date. Par
  defaut 289 pour une Assemblee de 577 membres.

- fichier:

  Chemin du fichier produit (PDF ou HTML).

- format:

  Format de sortie : auto, pdf ou html. En mode auto, HTML est utilise
  si pdflatex n'est pas disponible.

- cache:

  Repertoire de la base locale.

- ouvrir:

  Ouvrir le PDF apres generation.

## Value

Chemin du PDF, invisiblement.
