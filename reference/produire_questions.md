# Produire un dossier PDF de questions ecrites

Produire un dossier PDF de questions ecrites

## Usage

``` r
produire_questions(
  questions,
  titre = "Questions ecrites de l'Assemblee nationale",
  dossier = "/tmp",
  ouvrir = TRUE,
  modele = NULL
)
```

## Arguments

- questions:

  Resultat de rechercher_questions(), avec les textes integraux.

- titre:

  Titre du dossier documentaire.

- dossier:

  Repertoire de sortie, par defaut /tmp.

- ouvrir:

  Ouvrir le PDF apres production.

- modele:

  Modele PDF commun du package.

## Value

Chemin du PDF, invisiblement.
