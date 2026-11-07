# Stockage local : les lectures ne declenchent aucun acces reseau.
.nettoyer_noms = function(x) {
  noms = iconv(names(x), from = "UTF-8", to = "ASCII//TRANSLIT")
  noms = tolower(gsub("[^a-zA-Z0-9]+", "_", noms))
  noms = gsub("^_+|_+$", "", noms)
  if (anyDuplicated(noms)) stop("Colonnes identiques apres normalisation.", call. = FALSE)
  names(x) = noms
  x
}

.base_an = function(cache) {
  dir.create(cache, recursive = TRUE, showWarnings = FALSE)
  con = DBI::dbConnect(duckdb::duckdb(), dbdir = file.path(cache, "assembleer.duckdb"))
  DBI::dbExecute(con, "CREATE TABLE IF NOT EXISTS sources (source VARCHAR PRIMARY KEY, url VARCHAR, etag VARCHAR, modified VARCHAR, controle TIMESTAMP, md5 VARCHAR)")
  DBI::dbExecute(con, "CREATE TABLE IF NOT EXISTS fichiers (source VARCHAR, chemin VARCHAR, crc VARCHAR, taille DOUBLE, PRIMARY KEY(source, chemin))")
  DBI::dbExecute(con, "CREATE TABLE IF NOT EXISTS deputes (identifiant VARCHAR)")
  DBI::dbExecute(con, "CREATE TABLE IF NOT EXISTS acteurs (uid VARCHAR PRIMARY KEY, nom VARCHAR, prenom VARCHAR)")
  DBI::dbExecute(con, "CREATE TABLE IF NOT EXISTS organes (uid VARCHAR PRIMARY KEY, code_type VARCHAR, libelle VARCHAR, libelle_abrege VARCHAR, couleur VARCHAR)")
  DBI::dbExecute(con, "CREATE TABLE IF NOT EXISTS amendements (uid VARCHAR PRIMARY KEY, numero VARCHAR, legislature INTEGER, titre VARCHAR, dispositif VARCHAR, expose VARCHAR, sort VARCHAR, dossier_ref VARCHAR, texte_ref VARCHAR)")
  DBI::dbExecute(con, "CREATE TABLE IF NOT EXISTS dossiers_legislatifs (uid VARCHAR, titre VARCHAR, texte_ref VARCHAR)")
  DBI::dbExecute(con, "CREATE TABLE IF NOT EXISTS scrutins (uid VARCHAR PRIMARY KEY, numero INTEGER, date DATE, titre VARCHAR, type_vote VARCHAR, sort VARCHAR, votants INTEGER, pour INTEGER, contre INTEGER, abstentions INTEGER)")
  DBI::dbExecute(con, "CREATE TABLE IF NOT EXISTS effectifs_groupes_scrutins (scrutin_uid VARCHAR, groupe_ref VARCHAR, total_groupe INTEGER, PRIMARY KEY(scrutin_uid, groupe_ref))")
  DBI::dbExecute(con, "CREATE TABLE IF NOT EXISTS votes (scrutin_uid VARCHAR, acteur_ref VARCHAR, groupe_ref VARCHAR, position VARCHAR, par_delegation BOOLEAN, PRIMARY KEY(scrutin_uid, acteur_ref))")
  con
}

#' Lire une table locale DuckDB
#' @param table Table disponible dans la base.
#' @param cache Repertoire de stockage local.
#' @return Un data.frame.
#' @export
lire_table = function(table = c("deputes", "acteurs", "organes", "scrutins", "votes", "effectifs_groupes_scrutins", "dossiers_legislatifs", "amendements"),
                      cache = tools::R_user_dir("assembleer", "cache")) {
  table = match.arg(table)
  fichier = file.path(cache, "assembleer.duckdb")
  if (!file.exists(fichier)) stop("Base absente : executer actualiser() une premiere fois")
  con = .base_an(cache)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  x = DBI::dbReadTable(con, table)
  if (table == "deputes") x = .nettoyer_noms(x)
  x
}

#' Deputes en exercice, depuis la base locale
#' @inheritParams lire_table
#' @export
deputes = function(cache = tools::R_user_dir("assembleer", "cache")) lire_table("deputes", cache)
#' Acteurs parlementaires
#'
#' Retourne les acteurs parlementaires de la base locale.
#' @inheritParams lire_table
#' @return Un data.frame.
#' @export
acteurs = function(cache = tools::R_user_dir("assembleer", "cache")) lire_table("acteurs", cache)
#' Organes parlementaires
#'
#' Retourne les organes parlementaires de la base locale.
#' @inheritParams lire_table
#' @return Un data.frame.
#' @export
organes = function(cache = tools::R_user_dir("assembleer", "cache")) lire_table("organes", cache)
#' Groupes politiques
#'
#' Retourne les organes correspondant aux groupes politiques.
#' @inheritParams lire_table
#' @return Un data.frame.
#' @export
groupes = function(cache = tools::R_user_dir("assembleer", "cache")) {
  fichier = file.path(cache, "assembleer.duckdb")
  if (!file.exists(fichier)) stop("Base absente : executer actualiser()")
  con = .base_an(cache)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  DBI::dbGetQuery(con, "SELECT * FROM organes WHERE code_type = 'GP'")
}
#' Scrutins publics
#'
#' Retourne les scrutins publics de la base locale.
#' @inheritParams lire_table
#' @return Un data.frame.
#' @export
scrutins = function(cache = tools::R_user_dir("assembleer", "cache")) lire_table("scrutins", cache)
#' Votes individuels
#'
#' Retourne les votes individuels de la base locale.
#' @inheritParams lire_table
#' @return Un data.frame.
#' @export
votes = function(cache = tools::R_user_dir("assembleer", "cache")) lire_table("votes", cache)
