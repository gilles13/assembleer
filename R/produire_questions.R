#' Produire un dossier PDF de questions ecrites
#'
#' @param questions Resultat de rechercher_questions(), avec les textes integraux.
#' @param titre Titre du dossier documentaire.
#' @param dossier Repertoire de sortie, par defaut /tmp.
#' @param ouvrir Ouvrir le PDF apres production.
#' @param modele Modele PDF commun du package.
#' @return Chemin du PDF, invisiblement.
#' @export
produire_questions = function(questions, titre = "Questions ecrites de l'Assemblee nationale",
                              dossier = "/tmp", ouvrir = TRUE,
                              modele = NULL) {
  colonnes = c("uid", "numero", "rubrique", "analyse", "groupe", "ministere",
               "date_question", "date_reponse", "question", "reponse")
  if (!is.data.frame(questions) || !all(colonnes %in% names(questions)))
    stop("questions doit etre un resultat de rechercher_questions().", call. = FALSE)
  if (!nrow(questions)) stop("Aucune question a exporter.", call. = FALSE)
  if (length(titre) != 1L || is.na(titre) || !nzchar(trimws(titre)))
    stop("titre doit etre une chaine non vide.", call. = FALSE)
  if (length(dossier) != 1L || is.na(dossier) || !nzchar(dossier))
    stop("dossier invalide.", call. = FALSE)
  esc = function(x) {
    x = as.character(x)
    x[is.na(x)] = ""
    .echapper_latex(x)
  }
  valeur = function(x, defaut = "Non renseigne") {
    if (is.na(x) || !nzchar(trimws(as.character(x)))) defaut else as.character(x)
  }
  paragraphe = function(x) {
    x = valeur(x, "Texte non disponible")
    x = gsub("\\r\\n?", "\n", x)
    blocs = strsplit(x, "\\n[[:space:]]*\\n", perl = TRUE)[[1L]]
    paste(vapply(blocs, function(b) {
      b = gsub("[[:space:]]+", " ", trimws(b))
      paste0(esc(b), "\\par")
    }, character(1)), collapse = "\n\n")
  }
  sections = c(
    paste0("\\section*{", esc(titre), "}"),
    paste0("Dossier documentaire : ", nrow(questions), " question(s) ecrite(s)."),
    "\\section*{Sommaire}"
  )
  for (i in seq_len(nrow(questions))) {
    q = questions[i, , drop = FALSE]
    sections = c(sections, paste0(i, ". Question n\\textsuperscript{o} ",
      esc(valeur(q$numero[[1L]], q$uid[[1L]])), " \u2014 ",
      esc(valeur(q$analyse[[1L]], "Sans intitule")), "\\par"))
  }
  for (i in seq_len(nrow(questions))) {
    q = questions[i, , drop = FALSE]
    numero = valeur(q$numero[[1L]], q$uid[[1L]])
    sections = c(sections,
      "\\clearpage",
      paste0("\\section*{", i, ". Question n\\textsuperscript{o} ", esc(numero), "}"),
      paste0("\\textbf{Objet :} ", esc(valeur(q$analyse[[1L]])), "\\par"),
      paste0("\\textbf{Rubrique :} ", esc(valeur(q$rubrique[[1L]])), "\\par"),
      paste0("\\textbf{Groupe :} ", esc(valeur(q$groupe[[1L]])), "\\par"),
      paste0("\\textbf{Ministere interroge :} ", esc(valeur(q$ministere[[1L]])), "\\par"),
      paste0("\\textbf{Publication de la question :} ", esc(valeur(q$date_question[[1L]])), "\\par"),
      paste0("\\textbf{Identifiant officiel :} ", esc(q$uid[[1L]]), "\\par"),
      "\\subsection*{Question}", paragraphe(q$question[[1L]]),
      "\\subsection*{Reponse}",
      if (is.na(q$reponse[[1L]]) || !nzchar(trimws(q$reponse[[1L]])))
        "Aucune reponse publiee dans les donnees importees."
      else paste0("\\textit{Publication : ", esc(valeur(q$date_reponse[[1L]])), "}\\par\n",
                  paragraphe(q$reponse[[1L]])))
  }
  sortie = file.path(dossier, paste0("assembleer-questions-", format(Sys.Date(), "%Y%m%d"), ".pdf"))
  chemin = .pdf_assembleer(titre, paste0(nrow(questions), " questions ecrites"),
                           paste(sections, collapse = "\n\n"), sortie, modele = modele)
  .ouvrir_pdf(chemin, ouvrir = ouvrir)
  invisible(chemin)
}
