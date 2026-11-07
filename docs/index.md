# assembleer

![Logo assembleer](reference/figures/logo_hexa.png)

Accéder aux données ouvertes de l’Assemblée nationale depuis R, avec un
stockage local DuckDB.

## Installation

\
[`install.packages`](https://rdrr.io/r/utils/install.packages.html)`(``"remotes"``)`\
`remotes``::`[`install_github`](https://remotes.r-lib.org/reference/install_github.html)`(``"gilles13/assembleer"``)`

## Démarrer

\
`assembleer``::`[`actualiser`](https://gilles13.github.io/assembleer/reference/actualiser.md)`(``)``  ``# télécharge ou vérifie les sources officielles`\
`assembleer``::`[`chercher_scrutins`](https://gilles13.github.io/assembleer/reference/chercher_scrutins.md)`(``"finance"``, limite ``=`` ``10``)`\
`assembleer``::`[`bilan_votes`](https://gilles13.github.io/assembleer/reference/bilan_votes.md)`(``par ``=`` ``"groupe"``)`

Les lectures sont locales : elles ne déclenchent pas de téléchargement.
