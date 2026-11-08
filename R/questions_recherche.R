#' Rechercher les questions ecrites de l'Assemblee nationale
#'
#' Recherche locale dans les questions de la XVIIe legislature deja importees
#' dans DuckDB. Les textes integraux sont conserves dans le resultat.
#' @param mots Un ou plusieurs mots ou expressions, tous requis (ET).
#' @param rubrique,groupe,ministere Filtres textuels facultatifs (sous-chaines,
#'   sans distinction de casse).
#' @param date_debut,date_fin Dates de publication de la question (incluses).
#' @param dans Chercher dans la question, la reponse, ou les deux.
#' @param limite Nombre maximal de resultats ; `NULL` pour tous.
#' @inheritParams requete
#' @return Un data.frame avec identifiant, metadonnees et textes integraux.
#' @export
rechercher_questions = function(mots = NULL, rubrique = NULL, groupe = NULL,
                                ministere = NULL, date_debut = NULL,
                                date_fin = NULL, dans = c("question", "reponse", "tout"),
                                limite = NULL,
                                cache = tools::R_user_dir("assembleer", "cache")) {
  dans = match.arg(dans)
  if (!is.null(limite)) {
    if (length(limite) != 1L || !is.numeric(limite) || is.na(limite) ||
        !is.finite(limite) || limite < 1 || limite != floor(limite) ||
        limite > .Machine$integer.max)
      stop("limite doit etre un entier strictement positif ou NULL.", call. = FALSE)
  }
  champs = c(
    "uid",
    "document->'identifiant'->>'numero' AS numero",
    "document->'indexationAN'->>'rubrique' AS rubrique",
    "document->'indexationAN'->'analyses'->>'analyse' AS analyse",
    "document->'auteur'->'identite'->>'acteurRef' AS auteur_ref",
    "document->'auteur'->'groupe'->>'abrege' AS groupe",
    "document->'minInt'->>'developpe' AS ministere",
    "TRY_CAST(document->'textesQuestion'->'texteQuestion'->'infoJO'->>'dateJO' AS DATE) AS date_question",
    "TRY_CAST(document->'textesReponse'->'texteReponse'->'infoJO'->>'dateJO' AS DATE) AS date_reponse",
    "document->'textesQuestion'->'texteQuestion'->>'texte' AS question",
    "document->'textesReponse'->'texteReponse'->>'texte' AS reponse"
  )
  clauses = character()
  params = list()
  ajouter = function(condition, valeur) {
    clauses <<- c(clauses, condition)
    params <<- c(params, list(valeur))
  }
  if (!is.null(mots)) {
    if (!is.character(mots) || anyNA(mots) || any(!nzchar(trimws(mots))))
      stop("mots doit contenir des chaines non vides.", call. = FALSE)
    colonnes = switch(dans, question = "question", reponse = "reponse",
                      tout = "concat_ws(' ', question, reponse)")
    for (mot in mots) ajouter(paste0("contains(lower(", colonnes, "), lower(?))"), mot)
  }
  for (nom in c("rubrique", "groupe", "ministere")) {
    valeur = get(nom)
    if (!is.null(valeur)) {
      if (!is.character(valeur) || length(valeur) != 1L ||
          is.na(valeur) || !nzchar(trimws(valeur)))
        stop(nom, " doit etre une chaine non vide.", call. = FALSE)
      ajouter(paste0("contains(lower(", nom, "), lower(?))"), valeur)
    }
  }
  for (nom in c("date_debut", "date_fin")) {
    valeur = get(nom)
    if (!is.null(valeur)) {
      date = as.Date(valeur)
      if (length(date) != 1L || is.na(date))
        stop(nom, " doit etre une date valide.", call. = FALSE)
      ajouter(paste0("date_question ", if (nom == "date_debut") ">=" else "<=", " CAST(? AS DATE)"),
              as.character(date))
    }
  }
  sql = paste0("WITH questions AS (SELECT ", paste(champs, collapse = ", "),
               " FROM questions_ecrites) SELECT * FROM questions",
               if (length(clauses)) paste0(" WHERE ", paste(clauses, collapse = " AND ")) else "",
               " ORDER BY date_question DESC NULLS LAST, uid",
               if (!is.null(limite)) paste0(" LIMIT ", as.integer(limite)) else "")
  resultat = requete(sql, params = params, cache = cache)
  colonnes_texte = c("rubrique", "analyse", "question", "reponse")
  resultat[colonnes_texte] = lapply(resultat[colonnes_texte], .decoder_entites_html)
  resultat
}

.decoder_entites_html = function(x) {
  vapply(x, function(texte) {
    if (is.na(texte) || !grepl("&(?:#[0-9]+|#[xX][0-9A-Fa-f]+|[A-Za-z][A-Za-z0-9]+);",
                               texte, perl = TRUE)) return(texte)
    html = paste0("<html><body>", gsub("<", "&lt;", texte, fixed = TRUE),
                  "</body></html>")
    xml2::xml_text(xml2::xml_find_first(xml2::read_html(charToRaw(html)), "//body"))
  }, character(1), USE.NAMES = FALSE)
}
