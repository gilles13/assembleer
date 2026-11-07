# Connexion en lecture seule : les analyses ne modifient jamais la base.
.connexion_lecture = function(cache) {
  fichier = file.path(cache, "assembleer.duckdb")
  if (!file.exists(fichier)) stop("Base absente : executer actualiser() une premiere fois", call. = FALSE)
  DBI::dbConnect(duckdb::duckdb(), dbdir = fichier, read_only = TRUE)
}

#' Executer une requete SQL sur les donnees locales
#' @param sql Requete SQL DuckDB (lecture seule).
#' @param params Parametres SQL pour les marqueurs `?`.
#' @param cache Repertoire local de la base.
#' @return Un data.frame.
#' @export
requete = function(sql, params = list(), cache = tools::R_user_dir("assembleer", "cache")) {
  con = .connexion_lecture(cache)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  DBI::dbGetQuery(con, sql, params = params)
}

#' Rechercher des scrutins
#' @param texte Expression recherchee dans le titre (sans tenir compte de la casse).
#' @param depuis,avant Bornes inclusives de date, facultatives.
#' @param limite Nombre maximal de scrutins retournes.
#' @inheritParams requete
#' @return Un data.frame, trie par date et numero decroissants.
#' @export
chercher_scrutins = function(texte = NULL, depuis = NULL, avant = NULL, limite = 100L,
                              cache = tools::R_user_dir("assembleer", "cache")) {
  stopifnot(length(limite) == 1L, is.numeric(limite), is.finite(limite), limite >= 1)
  clauses = character()
  params = list()
  if (!is.null(texte)) {
    stopifnot(length(texte) == 1L, !is.na(texte))
    clauses = c(clauses, "contains(lower(titre), lower(?))")
    params = c(params, list(texte))
  }
  if (!is.null(depuis)) {
    clauses = c(clauses, "date >= CAST(? AS DATE)")
    params = c(params, list(as.character(as.Date(depuis))))
  }
  if (!is.null(avant)) {
    clauses = c(clauses, "date <= CAST(? AS DATE)")
    params = c(params, list(as.character(as.Date(avant))))
  }
  sql = paste0("SELECT * FROM scrutins",
               if (length(clauses)) paste0(" WHERE ", paste(clauses, collapse = " AND ")) else "",
               " ORDER BY date DESC, numero DESC LIMIT ", as.integer(limite))
  requete(sql, params = params, cache = cache)
}

#' Votes nominatifs d'un scrutin
#' @param scrutin_uid Identifiant du scrutin.
#' @inheritParams requete
#' @return Votes enrichis des noms des deputes et du groupe au moment du vote.
#' @export
votes_scrutin = function(scrutin_uid, cache = tools::R_user_dir("assembleer", "cache")) {
  requete("SELECT v.scrutin_uid, v.acteur_ref, a.nom, a.prenom,
                 v.groupe_ref, o.libelle_abrege AS groupe, v.position, v.par_delegation
           FROM votes v
           LEFT JOIN acteurs a ON a.uid = v.acteur_ref
           LEFT JOIN organes o ON o.uid = v.groupe_ref
           WHERE v.scrutin_uid = ?
           ORDER BY groupe, nom, prenom", list(scrutin_uid), cache)
}

#' Bilan des votes par groupe ou par depute
#' @param par Niveau de regroupement : groupe ou depute.
#' @param depuis,avant Bornes de date inclusives, facultatives.
#' @inheritParams requete
#' @return Nombre de votes pour, contre, abstentions et non-votants.
#' @export
bilan_votes = function(par = c("groupe", "depute"), depuis = NULL, avant = NULL,
                        cache = tools::R_user_dir("assembleer", "cache")) {
  par = match.arg(par)
  cle = if (par == "groupe") "v.groupe_ref" else "v.acteur_ref"
  libelle = if (par == "groupe") "o.libelle_abrege" else "concat_ws(' ', a.prenom, a.nom)"
  jointure = if (par == "groupe") "LEFT JOIN organes o ON o.uid = v.groupe_ref" else
    "LEFT JOIN acteurs a ON a.uid = v.acteur_ref"
  clauses = character()
  params = list()
  if (!is.null(depuis)) {
    clauses = c(clauses, "s.date >= CAST(? AS DATE)")
    params = c(params, list(as.character(as.Date(depuis))))
  }
  if (!is.null(avant)) {
    clauses = c(clauses, "s.date <= CAST(? AS DATE)")
    params = c(params, list(as.character(as.Date(avant))))
  }
  sql = paste0("SELECT ", cle, " AS uid, ", libelle, " AS libelle, ",
               "count(*) AS total, ",
               "count(*) FILTER (WHERE v.position = 'pour') AS pour, ",
               "count(*) FILTER (WHERE v.position = 'contre') AS contre, ",
               "count(*) FILTER (WHERE v.position = 'abstention') AS abstentions, ",
               "count(*) FILTER (WHERE v.position = 'non_votant') AS non_votants ",
               "FROM votes v JOIN scrutins s ON s.uid = v.scrutin_uid ", jointure,
               if (length(clauses)) paste0(" WHERE ", paste(clauses, collapse = " AND ")) else "",
               " GROUP BY 1, 2 ORDER BY total DESC, libelle")
  requete(sql, params, cache)
}
