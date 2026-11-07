# Cheatsheet

# assembleer · Cheatsheet

Les données de l’Assemblée nationale avec R

![Logo assembleer](../reference/figures/logo_hexa.png)

## Actualiser

## Démarrer

Charger assembleer et afficher cette fiche.

    library(assembleer)
    produire_cheatsheet()

## Mettre à jour

Télécharger les données officielles.

    actualiser(sources = c("deputes", "amo40",
                          "scrutins", "dossiers"))

## Actualisation forcée

Recharger une source particulière.

    actualiser(sources = "scrutins", forcer = TRUE)

## Lire les données

Explorer le cache local et interroger en SQL.

    lire_table("scrutins")
    requete("SELECT * FROM scrutins LIMIT 10")

## Explorer

## Acteurs et groupes

Consulter les personnes et les organes.

    deputes()
    groupes()
    acteurs()
    organes()

## Scrutins et votes

Explorer les scrutins et les votes.

    scrutins()
    votes()

## Rechercher

Trouver un scrutin et consulter ses votes.

    chercher_scrutins("finance", limite = 10)
    s = chercher_scrutins("finance", limite = 1)
    if (nrow(s)) votes_scrutin(s$uid[[1]])

## Amendements

Rechercher des amendements.

    chercher_amendements("finance")

## Analyser

## Bilan des votes

Comparer les résultats par groupe ou député.

    bilan_votes(par = "groupe")
    bilan_votes(par = "depute")

## Bilan hebdomadaire

Synthétiser une semaine de travaux.

    bilan_hebdomadaire(as.Date("2026-10-26"))

## Produire un PDF

Créer un document de synthèse.

    produire_bilan(as.Date("2026-10-26"))

## Fiches

Produire des fiches de composition.

    fiche_composition()
    fiche_deputes_groupes()
