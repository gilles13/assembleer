#' Rechercher les sujets des debats parlementaires
#'
#' Retourne les identifiants necessaires a produire_debat(). La nature est
#' derivee des codes officiels, sans classification thematique artificielle.
#' @param texte Recherche insensible a la casse dans le titre officiel.
#' @param nature Une ou plusieurs natures : question_gouvernement,
#'   question_orale, texte_legislatif, sous_partie, discussion_generale,
#'   discussion_articles, autre.
#' @param fichier Restreindre a une seance (chemin XML interne).
#' @param limite Nombre maximal de resultats.
#' @param cache Repertoire de la base DuckDB.
#' @return data.frame des points, titres et natures.
#' @export
catalogue_debats = function(texte = NULL, nature = NULL, fichier = NULL,
                             limite = 100L,
                             cache = tools::R_user_dir("assembleer", "cache")) {
  if (length(limite) != 1L || is.na(limite) || !is.finite(limite) || limite < 1)
    stop("limite doit etre un entier positif.", call. = FALSE)
  conditions = c("p.titre IS NOT NULL", "TRIM(p.titre) <> ''")
  params = list()
  if (!is.null(texte)) {
    conditions = c(conditions, "contains(lower(p.titre), lower(?))")
    params = c(params, list(texte))
  }
  if (!is.null(fichier)) {
    conditions = c(conditions, "p.fichier = ?")
    params = c(params, list(fichier))
  }
  nature_sql = "CASE
    WHEN code LIKE 'QG_%' THEN 'question_gouvernement'
    WHEN code LIKE 'QOSD_%' THEN 'question_orale'
    WHEN code = 'TITRE_TEXTE_DISCUSSION' THEN 'texte_legislatif'
    WHEN code = 'SOUS_TITRE_TEXTE_DISCUSSION' THEN 'sous_partie'
    WHEN code LIKE 'DISC_GENERALE_%' THEN 'discussion_generale'
    WHEN code LIKE 'DISC_ARTICLES_%' THEN 'discussion_articles'
    ELSE 'autre' END"
  sql = paste0("WITH points AS (SELECT p.fichier, p.position, p.id_syceron, p.titre,
    json_extract_string(p.attributs_json, '$.code_grammaire') AS code
    FROM debats_points p WHERE ", paste(conditions, collapse = " AND "),
    ") SELECT fichier, position, id_syceron, titre, code, ", nature_sql,
    " AS nature FROM points")
  if (!is.null(nature)) {
    valeurs = c("question_gouvernement", "question_orale", "texte_legislatif",
                "sous_partie", "discussion_generale", "discussion_articles", "autre")
    if (!length(nature) || anyNA(nature) || !all(nature %in% valeurs))
      stop("Nature inconnue.", call. = FALSE)
    sql = paste0("SELECT * FROM (", sql, ") x WHERE nature IN (",
                  paste(rep("?", length(nature)), collapse = ","), ")")
    params = c(params, as.list(nature))
  }
  sql = paste0(sql, " ORDER BY fichier, position LIMIT ", as.integer(limite))
  requete(sql, params = params, cache = cache)
}
