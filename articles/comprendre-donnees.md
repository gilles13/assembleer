# Comprendre les données de l'Assemblée nationale

Cette page documente progressivement les données **réellement importées
dans assembleer**. Elle distingue les observations faites dans la base
DuckDB, les interprétations possibles et les points qui restent à
vérifier. Elle ne décrit pas l’ensemble des données publiées par
l’Assemblée nationale.

## Relevé historique du schéma (avant les nouveaux imports)

Le **relevé historique** présenté ci-dessous comportait **11 tables**.
Les colonnes ci-dessous sont celles relevées dans
`information_schema.columns` ; les nombres de lignes proviennent de
comptages SQL lorsqu’ils ont été effectués, sinon d’estimations DuckDB.

| Table | Contenu | Colonnes | Volume observé |
|:---|:---|:---|---:|
| `acteurs` | Identité des acteurs | `uid`, `nom`, `prenom` | ~646 |
| `deputes` | Informations sur les députés | `identifiant`, `prenom`, `nom`, `region`, `departement`, `numero_de_circonscription`, `profession`, `groupe_politique_complet`, `groupe_politique_abrege` | ~574 |
| `organes` | Groupes, commissions et autres organes | `uid`, `code_type`, `libelle`, `libelle_abrege`, `couleur` | ~9 671 |
| `scrutins` | Scrutins publics et résultats agrégés | `uid`, `numero`, `date`, `titre`, `type_vote`, `sort`, `votants`, `pour`, `contre`, `abstentions` | **9 759** |
| `votes` | Positions individuelles aux scrutins | `scrutin_uid`, `acteur_ref`, `groupe_ref`, `position`, `par_delegation` | **1 447 623** |
| `effectifs_groupes_scrutins` | Effectifs des groupes associés aux scrutins | `scrutin_uid`, `groupe_ref`, `total_groupe` | **116 940** |
| `dossiers_legislatifs` | Identification des dossiers législatifs | `uid`, `titre`, `texte_ref` | ~7 254 |
| `amendements` | Amendements (non chargés actuellement) | `uid`, `numero`, `legislature`, `titre`, `dispositif`, `expose`, `sort`, `dossier_ref`, `texte_ref` | **0** |
| `sources` | Suivi des sources importées | `source`, `url`, `etag`, `modified`, `controle`, `md5` | ~19 |
| `fichiers` | Inventaire des fichiers téléchargés | `source`, `chemin`, `crc`, `taille` | ~59 526 |
| `fichiers_uid` | Correspondance entre fichiers et identifiants | `source`, `chemin`, `uid`, `table_cible` | ~20 081 |

*Les valeurs précédées de « ~ » proviennent de
`duckdb_tables().estimated_size` et ne sont pas des comptages exacts.*

## Comment les tables se relient

Le noyau le plus exploitable aujourd’hui est celui des **scrutins** :

- `scrutins.uid` correspond vraisemblablement à `votes.scrutin_uid` et à
  `effectifs_groupes_scrutins.scrutin_uid`.
- `votes.acteur_ref` est une référence à rapprocher de `acteurs.uid`.
- `votes.groupe_ref` et `effectifs_groupes_scrutins.groupe_ref` sont à
  rapprocher de `organes.uid`, pour les organes de type `GP` et les
  catégories pertinentes.
- `dossiers_legislatifs.texte_ref` peut servir à rapprocher des
  documents, mais les étapes et dates de procédure ne figurent pas dans
  cette table.

Ces relations sont **déduites des noms et des premiers rapprochements**
; leur couverture et l’unicité des clés restent à contrôler. La table
`deputes` utilise `identifiant`, et son lien avec `acteurs.uid` n’est
pas encore établi.

## Comprendre les votes

La table `votes` enregistre quatre positions :

| Position     | Nombre de lignes |
|:-------------|-----------------:|
| `contre`     |          711 294 |
| `pour`       |          624 791 |
| `abstention` |           86 111 |
| `non_votant` |           25 427 |
| **Total**    |    **1 447 623** |

Ce sont des **positions enregistrées**, pas des nombres de députés
distincts. Une même personne peut apparaître dans de nombreux scrutins.
`non_votant` est une modalité explicite : il ne faut pas la confondre
sans vérification avec l’absence d’une ligne de vote.

Les **9 759 scrutins** observés se répartissent ainsi :

| Type                     | Résultat | Nombre |
|:-------------------------|:---------|-------:|
| Scrutin public ordinaire | Rejeté   |  6 515 |
| Scrutin public ordinaire | Adopté   |  3 146 |
| Scrutin public solennel  | Adopté   |     70 |
| Scrutin public solennel  | Rejeté   |      5 |
| Motion de censure        | Rejetée  |     22 |
| Motion de censure        | Adoptée  |      1 |

Les votes individuels permettent d’étudier la participation, la cohésion
interne des groupes et les proximités de vote. Ces indicateurs
nécessitent des définitions explicites, notamment pour les absences, les
abstentions et les changements d’affiliation.

## Contrôles de cohérence effectués

Les contrôles suivants ont été exécutés sur la base locale étudiée
(novembre 2026) :

| Contrôle | Observations | Anomalies détectées |
|:---|---:|---:|
| Concordance des décomptes `pour`, `contre`, `abstention` entre `scrutins` et `votes` | 9 759 scrutins | 0 |
| Unicité de `(scrutin_uid, acteur_ref)` et absence de références nulles dans `votes` | 1 447 623 votes | 0 |
| Unicité de `(scrutin_uid, groupe_ref)` et effectifs strictement positifs | 116 940 effectifs | 0 |
| Participants enregistrés inférieurs ou égaux aux effectifs correspondants | 106 743 couples scrutin–groupe | 0 |

Ces vérifications portent sur les propriétés indiquées ; elles ne
prouvent pas que tous les rattachements politiques sont corrects.

## Le cas particulier de `PO0`

`votes.groupe_ref` comporte **14 références distinctes**, dont 13
identifiées dans `organes`. La référence **`PO0`** n’a pas de
correspondance dans `organes` ni d’effectif dans
`effectifs_groupes_scrutins`. Elle n’est pas synonyme de « non-inscrit »
: les non-inscrits ont la référence `PO840056`.

**1 916 votes** sont associés à `PO0`, dans **14 scrutins** :

- Douze scrutins du **2 décembre 2024** (numéros 489, 491 à 501) : tous
  les votes enregistrés portent `PO0`.
- Scrutin **1302 du 7 avril 2025** : 73 votes `PO0` sur 288, tous
  `contre`.
- Scrutin **6256 du 16 avril 2026** : 17 votes `PO0` sur 112, tous
  `contre`.

Ces 14 scrutins n’ont **aucun effectif historique enregistré**. Les deux
derniers contiennent néanmoins des votes correctement associés à
d’autres groupes. Les 9 745 autres scrutins disposent d’effectifs
historiques.

La fiche publique du [scrutin
1302](https://www.assemblee-nationale.fr/dyn/17/scrutins/1302) présente
73 votes contre du Rassemblement national, ce qui correspond au nombre
et à la position des 73 votes `PO0` observés dans notre base. Cette
concordance constitue un indice de rattachement manquant, **pas une
preuve suffisante pour réaffecter automatiquement ces votes**.

### Ce que fait actuellement le code d’importation

Dans `R/actualisation.R`, `.extraire_an()` recopie `g$organeRef` du JSON
officiel vers `votes.groupe_ref` et vers les effectifs, sans fabriquer
la valeur `PO0`. En revanche, `.importer_effectifs_groupes()` **ignore
volontairement tout le scrutin** dès qu’un des groupes porte la
référence `PO0`. Ce choix explique l’absence d’effectifs pour les 14
scrutins dans la base étudiée, y compris pour les groupes identifiés
dans les deux scrutins mixtes.

La cause initiale de `PO0` doit être établie en examinant les
`organeRef` des groupes dans les fichiers JSON sources. Il faut
distinguer un `PO0` déjà présent dans le fichier officiel d’une erreur
de transformation ailleurs dans la chaîne. Aucune correction automatique
des références n’est justifiée à ce stade.

Deux autres références doivent rester distinctes jusqu’à vérification de
leur chronologie : « UDR » (`PO847173`) et « Union des droites pour la
République » (`PO872880`).

## Participation aux scrutins publics

L’indicateur exploratoire utilise les effectifs historiques comme base
et compte comme participants les positions `pour`, `contre` et
`abstention` ; `non_votant` est exclu du numérateur. Un couple
scrutin–groupe avec effectif connu et aucun vote enregistré contribue
**zéro participation**, mais conserve son effectif au dénominateur.

``` math
\text{Participation (\%)} = 100 \times
\frac{\sum \text{participants enregistrés}}{\sum \text{effectifs historiques}}
```

Sur **116 940 couples scrutin–groupe**, dont **10 197 sans vote
enregistré**, les taux calculés sont :

| Groupe                                            | Taux (%) |
|:--------------------------------------------------|---------:|
| Rassemblement national                            |     34,1 |
| La France insoumise – Nouveau Front populaire     |     31,0 |
| Écologiste et Social                              |     27,7 |
| Socialistes et apparentés                         |     26,2 |
| UDR (`PO847173`)                                  |     24,0 |
| Union des droites pour la République (`PO872880`) |     22,9 |
| Ensemble pour la République                       |     21,9 |
| Horizons & Indépendants                           |     21,8 |
| Les Démocrates                                    |     21,4 |
| Droite Républicaine                               |     17,3 |
| Gauche Démocrate et Républicaine                  |     13,8 |
| LIOT                                              |     11,8 |
| Non-inscrits                                      |     11,7 |

Ces taux mesurent la participation **aux scrutins publics enregistrés**,
pas la présence physique des députés ni l’ensemble de leur activité. Les
14 scrutins sans effectifs historiques ne sont pas compris dans ces
taux.

## Ce que nous pouvons mesurer dès maintenant

| Synthèse | Tables nécessaires | Ce que cela mesure |
|:---|:---|:---|
| Nombre de scrutins par mois | `scrutins` | Intensité et calendrier des scrutins publics |
| Répartition des résultats | `scrutins` | Fréquence des scrutins adoptés ou rejetés, par type |
| Participation par groupe | `votes`, `effectifs_groupes_scrutins`, `scrutins` | Part des membres ayant une participation enregistrée lors des scrutins, sous réserve de valider les dénominateurs |
| Cohésion d’un groupe | `votes` | Part des participants partageant la position la plus fréquente du groupe |
| Proximité entre groupes | `votes` | Concordance des positions majoritaires lors des mêmes scrutins |
| Évolution des effectifs aux scrutins | `effectifs_groupes_scrutins`, `scrutins` | Taille des groupes aux dates où des scrutins ont eu lieu |

Dans le relevé historique décrit dans cette section, la base ne
contenait ni les **dates de dépôt** ni les **étapes détaillées** des
dossiers législatifs. Elle ne permet donc pas encore de mesurer les
délais des procédures. Les réunions de commissions et les questions au
Gouvernement ne disposaient pas non plus de tables dédiées dans ce
schéma historique.

## Contrôles à poursuivre

1.  Examiner les valeurs `organeRef` des groupes dans les JSON originaux
    des scrutins 489, 1302 et 6256 afin de déterminer l’origine de
    `PO0`.
2.  Vérifier la couverture des références aux acteurs et aux organes.
3.  Documenter les périodes couvertes par les deux identifiants UDR.
4.  Documenter la période et les législatures couvertes par les données
    importées.

Cette vignette sera enrichie au fur et à mesure des contrôles et des
nouvelles sources intégrées à assembleer.

## Données intégrées depuis le relevé initial (8 novembre 2026)

Les tableaux de la première partie sont un **instantané historique**, et
non l’inventaire actuel de DuckDB. Les ajouts ci-dessous sont établis à
partir des importateurs du package et, lorsque c’est indiqué, des
comptages réalisés sur la base de travail. Ils ne doivent pas être
additionnés aux volumes historiques sans requête sur la base courante.

| Corpus | Tables DuckDB | Granularité et informations conservées | État de vérification |
|:---|:---|:---|:---|
| AN — acteurs et mandats (AMO20) | `acteurs`, `organes`, `mandats`, `mandats_organes` | Identité, organisme, type et qualité du mandat, dates de début/fin et rattachements | Importeur présent dans [`actualiser()`](https://gilles13.github.io/assembleer/reference/actualiser.md) ; 35 163 mandats distincts observés lors de l’import de travail |
| AN — réunions | `reunions`, `reunions_points_odj` | Réunion et points d’ordre du jour, avec références documentaires | Importeur présent ; rapprochements partiels décrits plus bas |
| AN — comptes rendus de séance | `debats_seances`, `debats_points`, `debats_paragraphes` | XML source, hiérarchie des points, identifiants Syceron, orateurs et interventions | 657 XML, 33 900 points et 1 898 occurrences de sujets de niveau 1 observés |
| DILA — DOLE | `dole.archives`, `dole.dossiers`, `dole.liens` | Archives, XML complet des dossiers `JORFDOLE...` et liens documentaires | Importeur global et incrémental présent ; couverture à recompter sur la base courante |
| Sénat — DOSLEG | 53 tables dans le schéma `senat` | Tables et colonnes du dump PostgreSQL officiel, conservées en `VARCHAR` | Importeur [`importer_dosleg()`](https://gilles13.github.io/assembleer/reference/importer_dosleg.md) présent ; effectifs par table à relever dans la base courante |

### Acteurs, mandats et appartenances : AMO20

L’archive officielle AMO20 est traitée par
`actualiser(sources = "amo20")`. L’import crée ou met à jour les acteurs
et organes, remplace les lignes de `mandats` et `mandats_organes`, et
conserve les dates des mandats. `mandats.uid` identifie le mandat ;
`mandats.acteur_uid` renvoie à `acteurs.uid` ; `mandats_organes` relie
les UID de mandats et d’organes. Un acteur peut avoir plusieurs mandats
successifs ou simultanés : il faut filtrer les dates pour interpréter
une prise de parole à une séance donnée. Les rattachements à un groupe
(`GP`) et à un ministère (`MINISTERE`) ne sont pas interchangeables.

### Débats de l’Assemblée nationale

[`importer_debats()`](https://gilles13.github.io/assembleer/reference/importer_debats.md)
conserve trois niveaux : une ligne par compte rendu
(`debats_seances.fichier`), des points hiérarchisés (`debats_points`,
avec `id_syceron`, `parent_id_syceron`, `position`, `titre` et
`attributs_json`) et des paragraphes (`debats_paragraphes`, avec
`point_id_syceron`, `id_acteur`, `orateurs_xml` et `texte`). La clé de
rattachement des points et paragraphes **inclut `fichier`** : une
référence Syceron isolée ne doit pas remplacer ce contexte sans
contrôle.

Les comptages effectués pendant l’exploration donnent **657 comptes
rendus XML**, **33 900 points**, **1 898 occurrences de points de niveau
1** et **507 titres distincts** après `TRIM(titre)`. Les 507 titres ne
représentent pas 507 dossiers législatifs : un titre peut revenir dans
plusieurs séances et certains points sont procéduraux (ouverture,
motion, déclaration). Les variantes d’espaces insécables peuvent aussi
créer des doublons apparents.

Pour retrouver les sujets et leurs références dans la base :

``` r

requete("
  SELECT DISTINCT TRIM(titre) AS titre, id_syceron AS reference
  FROM debats_points
  WHERE TRY_CAST(json_extract_string(attributs_json, '$.nivpoint')
                 AS INTEGER) = 1
    AND NULLIF(TRIM(titre), '') IS NOT NULL
  ORDER BY titre, reference
")
```

Le catalogue identifie des **occurrences de débats**, non des dossiers
consolidés sur l’ensemble de la navette parlementaire. Aucune
correspondance entre débats et dossiers DOLE ne doit être déduite de la
seule ressemblance des titres.

### DOLE : dossiers de la DILA

[`importer_dole()`](https://gilles13.github.io/assembleer/reference/importer_dole.md)
télécharge avec `system2("curl", ...)` le stock global DOLE et ses mises
à jour, conserve les XML dans `dole.dossiers` et extrait les attributs
`libelle` et `lien` des éléments `LIEN` dans `dole.liens` (colonne SQL
`url`). La version la plus récente d’un dossier remplace son état
précédent ; `dole.archives` permet de suivre les livraisons.

Le titre principal d’un XML est à l’emplacement
`/DOSSIER_LEGISLATIF/META/META_DOSSIER_LEGISLATIF/TITRE` ; les documents
peuvent nécessiter `xml2::read_xml(..., options = "HUGE")`. Les
références `JORFDOLE...` ne sont **pas** des références Syceron ou
`DLR...`. Une première comparaison exacte des libellés « Pour
comprendre… » de `dole.liens` a relié **26 titres sur 507** ; ce
résultat mesure uniquement cette règle de rapprochement et ne constitue
pas une mesure de couverture générale des dossiers.

### Sénat : DOSLEG, source intégrée et travaux à poursuivre

[`importer_dosleg()`](https://gilles13.github.io/assembleer/reference/importer_dosleg.md)
utilise `system2("curl", ...)` pour obtenir
<https://data.senat.fr/data/dosleg/dosleg.zip>, lit le fichier
`dosleg.sql` sans serveur PostgreSQL, puis importe ses **53 tables**
dans le schéma `senat`. Les colonnes sont conservées en `VARCHAR` afin
de préserver les codes et valeurs d’origine. L’archive est mise en cache
et l’import est identifié par son empreinte MD5 dans
`importations_officielles` ; un changement d’archive peut déclencher un
rechargement transactionnel du schéma.

Les 53 tables ne doivent pas être présentées comme 53 jeux de données
indépendants : elles constituent un **modèle relationnel**. Avant d’en
exploiter les liens avec l’AN, il reste à relever les noms de tables,
les clés documentaires, les dates et les effectifs réels. L’existence de
DOSLEG ne signifie pas que les comptes rendus intégraux du Sénat, AMELI
ou BASILE sont déjà importés : ces corpus figurent dans le catalogue
éditorial `sources_senat.csv` et doivent être étudiés séparément.

Inventaire reproductible des tables sénatoriales :

``` r

requete("
  SELECT table_name, estimated_size
  FROM duckdb_tables()
  WHERE schema_name = 'senat'
  ORDER BY table_name
")
```

Les autres sources sénatoriales prioritaires recensées sont les comptes
rendus intégraux des séances, les amendements AMELI, les questions
BASILE, les données sur les sénateurs et les comptes rendus de
commissions. Le catalogue `inst/extdata/sources_senat.csv` indique pour
chacune la page officielle, la granularité, la couverture annoncée, les
formats et les points à vérifier. **Recensé ne signifie pas importé.**

### Prochaine étape : inventaire des manques

Avant de développer de nouveaux importateurs, examiner les catalogues
`sources_an.csv`, `sources_senat.csv` et `sources_divers.csv`, vérifier
les URL et formats officiels avec `system2("curl", ...)`, puis
documenter sur des échantillons les identifiants, relations, dates et
champs disponibles. Priorité aux sources qui complètent les données déjà
présentes (Sénat : comptes rendus, AMELI, BASILE ; AN : questions et
amendements selon leur couverture réelle), sans créer de rapprochements
non démontrés.

## Dossiers législatifs : rapprochement entre les deux chambres (novembre 2026)

Cette section rapporte une exploration distincte de l’état historique
décrit plus haut. La base DuckDB examinée comporte désormais notamment
`reunions`, `reunions_points_odj`, `debats_seances`, `debats_points` et
`debats_paragraphes`. Les volumes des sections précédentes correspondent
à un relevé antérieur et ne doivent pas être interprétés comme un état à
jour.

### Sources et rôle de chacune

Trois catalogues éditoriaux sont maintenus séparément dans
`inst/extdata/` : `sources_an.csv` (22 entrées), `sources_senat.csv`
(13) et `sources_divers.csv` (10). Ils utilisent les colonnes `famille`,
`jeu`, `page_officielle`, `granularite`, `priorite`, `couverture`,
`formats_confirmes` et `points_a_verifier`. La valeur `support` de
`priorite` est conservée pour quatre entrées AN ; les autres priorités
sont `1`, `2` ou `3`. Ces fichiers recensent des sources potentielles :
leur présence ne signifie pas que les données correspondantes ont été
importées dans DuckDB.

- **Assemblée nationale** : dossiers, textes, réunions, débats,
  amendements, scrutins et acteurs. `dossiers_legislatifs.uid` identifie
  le dossier AN ; `texte_ref` référence des textes, parfois issus du
  Sénat.
- **DOLE (DILA)** : dossiers `JORFDOLE...`, diffusés sous forme
  d’archives XML sur <https://echanges.dila.gouv.fr/OPENDATA/DOLE/>. Les
  éléments `LIEN` peuvent contenir, dans leurs attributs `libelle` et
  `lien`, les URL des dossiers AN et Sénat. DOLE fournit donc des
  **liens documentaires**, pas directement une clé `DLR...`.
- **Sénat** : DOSLEG, comptes rendus, AMELI, questions et autres sources
  à étudier pour compléter les étapes et échanges de la seconde chambre.
- **JORF / LEGI** : pistes de raccordement ultérieur entre dossiers,
  promulgation et textes en vigueur ; aucun raccordement n’a été validé
  lors de cette exploration.

### Échantillon DOLE effectivement examiné

L’archive de mise à jour `DOLE_20261103-214151.tar.gz` contient trois
fichiers XML. Les liens de dossier législatif extraits sont les suivants
:

| Dossier DOLE | Dossier AN identifié dans DuckDB | URL AN (suffixe) | URL Sénat (suffixe) |
|:---|:---|:---|:---|
| `JORFDOLE000054148224` | `DLR5L17N52767` | `/dyn/17/dossiers/abrogation_code_noir` | `/dossier-legislatif/ppl25-672.html` |
| `JORFDOLE000054936525` | `DLR5L17N54951` | `/dyn/17/dossiers/PLFSS_2027` | `/dossier-legislatif/plfss2027.html` |
| `JORFDOLE000054936498` | `DLR5L17N54629` | `/dyn/17/dossiers/PLF_2027` | Aucun lien Sénat dans l’échantillon |

Les suffixes AN sont relatifs à `https://www.assemblee-nationale.fr` ;
les suffixes Sénat à `https://www.senat.fr`. Les UID AN ont été
retrouvés dans `dossiers_legislatifs` avec les titres « Abrogation du
Code noir », « Projet de loi de financement de la sécurité sociale pour
2027 » et « Projet de loi de finances pour 2027 ». Le rapprochement a
été effectué **manuellement par les titres et URL** : il ne constitue
pas encore une jointure automatique démontrée entre `JORFDOLE...` et
`DLR...`.

Dans ces trois dossiers AN, les références textuelles observées sont :

| Dossier AN      | Lignes `texte_ref` | Avec `ANR` | Avec `SNR` |
|:----------------|-------------------:|-----------:|-----------:|
| `DLR5L17N52767` |                  8 |          4 |          3 |
| `DLR5L17N54629` |                 11 |         10 |          0 |
| `DLR5L17N54951` |                  7 |          4 |          2 |

### Couverture des références dans la base locale

Une requête sur les **3 402 UID distincts** de `dossiers_legislatifs` a
donné les résultats suivants :

| Indicateur                                  | Dossiers | Part du total |
|:--------------------------------------------|---------:|--------------:|
| Avec au moins une référence contenant `SNR` |    1 005 |        29,5 % |
| Avec au moins une référence contenant `ANR` |    2 852 |        83,8 % |
| Avec les deux types de références           |      479 |        14,1 % |

Les pourcentages ont pour dénominateur les 3 402 dossiers distincts. Ils
mesurent uniquement la **présence des chaînes `SNR` et `ANR`** dans
`texte_ref` ; ils ne mesurent ni le nombre de dossiers réellement
examinés par les deux chambres, ni l’exhaustivité des archives, ni les
échanges reconstitués. L’absence de `SNR` n’implique pas une absence de
travaux sénatoriaux.

La table `dossiers_legislatifs` comporte plusieurs lignes par `uid` :
une ligne par référence de texte observée dans cet import. Pour compter
les dossiers, employer `COUNT(DISTINCT uid)` ; ne pas interpréter
`COUNT(*)` comme un nombre de dossiers.

### Relations à vérifier avant intégration

Le chemin documentaire à examiner est `dossiers_legislatifs.uid` →
`reunions_points_odj.dossier_ref` → `reunions_points_odj.reunion_ref` →
`reunions.uid` → `reunions.compte_rendu_ref` → `debats_seances.uid`. Sur
les points d’ordre du jour ayant une référence de dossier, **3 203**
points avaient une réunion retrouvée, **3 013** une référence de compte
rendu et **910** un compte rendu retrouvé dans `debats_seances`. Ce
dernier résultat ne prouve pas que les autres comptes rendus manquent à
la source : le périmètre des débats importés et celui des réunions
diffèrent, notamment pour les commissions et le Sénat. Il reste à
vérifier le rattachement des interventions à un **point précis** de
l’ordre du jour ; une séance entière ne doit pas être attribuée à chaque
dossier qu’elle mentionne.

**Suite retenue** : documenter les identifiants et les relations DOSLEG,
les comptes rendus de commissions et les questions parlementaires avant
de créer des tables supplémentaires. Ne pas déduire de correspondances
entre UID sur la seule similitude des titres.

### Sénateurs : dump PostgreSQL et annuaire PDF

La source [Les sénateurs (Sénat)](https://data.senat.fr/les-senateurs/)
fournit l’archive `export_sens.zip`, contenant le dump PostgreSQL
`export_sens.sql`. `actualiser(sources = "senateur")` contrôle la source
selon le délai `jours` (un jour par défaut), télécharge les données si
nécessaire et importe les tables si le contenu a changé ou si une
réimportation est demandée. L’archive est conservée dans le cache local.

``` r

assembleer::actualiser(sources = "senateur")
assembleer::actualiser(sources = "senateur", reimporter = TRUE)
```

Les **95 tables** du dump sont importées dans le schéma DuckDB
`senateurs` de la base `assembleer.duckdb`, sans serveur PostgreSQL. La
table `senateurs.sen` comprend les identités, professions, groupes
politiques, rattachements et statuts (`ACTIF`, `ANCIEN`, `AUTRE`). Lors
du premier import étudié, elle comportait 2 015 personnes : 348 en
exercice, 1 664 anciennes et 3 autres.

La fonction
[`produire_senateurs()`](https://gilles13.github.io/assembleer/reference/produire_senateurs.md)
génère un annuaire PDF à partir de la base locale, avec le modèle commun
`inst/modeles/template.Rmd`, sans `fancyhdr` et sans nouveau
téléchargement :

``` r

assembleer::produire_senateurs(type = "actif")
assembleer::produire_senateurs(type = "anciens", ouvrir = FALSE)
assembleer::produire_senateurs(type = "autres", ouvrir = FALSE)
assembleer::produire_senateurs(type = "tous", ouvrir = FALSE)
```

Les PDF sont écrits dans `/tmp` par défaut. Chaque entrée indique
l’identifiant, le nom, le prénom, le groupe, le code de rattachement
(tel que fourni par la source), la profession, la circonscription et la
commission. Le statut figure aussi dans l’annuaire complet.

## Questions écrites de l’Assemblée nationale

Les questions écrites de la XVIIe législature sont distribuées dans
[l’archive
officielle](https://data.assemblee-nationale.fr/questions/questions-ecrites)
au format ZIP contenant un fichier JSON par question.

``` r

assembleer::actualiser(sources = "questions_ecrites", verbose = TRUE)
questions = assembleer::lire_table("questions_ecrites")
nrow(questions)
```

Les données sont conservées dans **DuckDB**, table
`main.questions_ecrites` : `uid` est l’identifiant officiel, `document`
conserve l’objet JSON complet. L’archive locale est mise en cache ;
l’importation est transactionnelle et n’a lieu que lorsque la source a
changé ou lors d’une réimportation demandée.

Les champs imbriqués restent interrogeables directement en SQL, sans
relire les fichiers d’origine :

``` r

con = assembleer:::.base_an(tools::R_user_dir("assembleer", "cache"))
DBI::dbGetQuery(con, "
  SELECT document->'auteur'->'groupe'->>'abrege' AS groupe,
         COUNT(*) AS questions
  FROM questions_ecrites
  GROUP BY 1 ORDER BY questions DESC
")
DBI::dbDisconnect(con, shutdown = TRUE)
```

Les informations comprennent notamment l’auteur, son groupe, le
ministère interrogé, le texte de la question, la réponse éventuelle, la
clôture et les réattributions ministérielles. Une clôture ne signifie
pas nécessairement qu’une réponse a été publiée.

### Rechercher les questions ecrites

La fonction
[`rechercher_questions()`](https://gilles13.github.io/assembleer/reference/rechercher_questions.md)
interroge la table DuckDB locale, sans nouvel acces au reseau. Elle
renvoie les textes integraux des questions et des reponses, avec les
dates, rubriques, groupes et ministeres.

``` r

# Expression presente dans le texte de la question
logement = assembleer::rechercher_questions(mots = "logement", limite = 20)

# Deux expressions obligatoires (ET), recherche dans question et reponse
resultats = assembleer::rechercher_questions(
  mots = c("logement", "social"), dans = "tout",
  date_debut = "2025-01-01", limite = 50
)

# Recherche par rubrique et groupe, sans mot-cle obligatoire
resultats = assembleer::rechercher_questions(
  rubrique = "logement", groupe = "RN", limite = 20
)
```

Les filtres textuels recherchent des sous-chaines sans distinction de
casse. `mots = c("logement", "social")` exige la presence des **deux**
expressions sur le champ choisi ; `dans = "tout"` examine les textes des
questions et reponses. `limite = NULL` retourne tous les resultats
correspondants. La recherche n’effectue ni lemmatisation ni
rapprochement semantique.

### Produire un dossier PDF de questions et reponses

La recherche peut etre transmise directement au moteur PDF du package :

``` r

x = rechercher_questions(mots = c("logement", "social"), limite = 5)
produire_questions(questions = x, titre = "Le logement social",
                   dossier = "/tmp", ouvrir = TRUE)
```

Le dossier reprend les textes complets, les dates de publication et les
metadonnees disponibles. Une question sans reponse est signalee comme
telle.
