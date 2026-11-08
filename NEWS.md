# assembleer 0.3.0

## Nouvelles sources de données

- **Assemblée nationale — questions écrites (XVIIe législature)** : téléchargement et import des fichiers JSON officiels dans `main.questions_ecrites`, avec conservation des documents complets, cache et actualisation contrôlée.
- **Assemblée nationale — acteurs, organes et mandats (AMO20)** : import des identités, organes, mandats et rattachements.
- **Assemblée nationale — comptes rendus de séance** : import des séances, points hiérarchisés et paragraphes des débats.
- **DILA — DOLE** : import du stock et des mises à jour des dossiers législatifs, avec extraction des liens documentaires.
- **Sénat — DOSLEG** : import du dump PostgreSQL officiel des dossiers législatifs dans DuckDB.
- **Sénat — sénateurs** : import du dump officiel des sénateurs dans le schéma `senateurs`.

## Nouvelles fonctionnalités

- `rechercher_questions()` : recherche locale dans les questions écrites, par mots ou expressions, rubrique, groupe, ministère et dates ; récupération possible de toutes les questions avec `limite = NULL`.
- Décodage des entités HTML dans les résultats des questions écrites (`œ`, `€`, etc.), sans modifier les JSON originaux stockés dans DuckDB.
- `produire_questions()` : dossier PDF regroupant les questions sélectionnées et leurs réponses publiées.
- `produire_senateurs()` : annuaire PDF des sénateurs, avec sélection par statut.
- Production et consultation de documents PDF sur les débats et les dossiers parlementaires ; enrichissement de la documentation des sources et des correspondances entre corpus.

## Documentation et site

- Suppression des grandes illustrations des vignettes et du site pour alléger les pages ; conservation du seul logo hexagonal.
- Actualisation du guide « Comprendre les données de l’Assemblée nationale » pour les nouveaux corpus.

