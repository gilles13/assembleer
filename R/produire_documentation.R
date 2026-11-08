#' Produire un inventaire documentaire officiel d'un dossier DOLE
#'
#' Construit un PDF a partir des liens explicites contenus dans DOLE.
#' Aucune jointure par titre ni date deduite des libelles.
#' @param uid Identifiant DOLE (JORFDOLE...).
#' @param sortie Chemin du PDF dans /tmp par defaut.
#' @param cache Cache local assembleer.
#' @param ouvrir Ouvrir le PDF apres generation.
#' @param modele Modele PDF commun du package.
#' @return Chemin du PDF, invisiblement.
#' @export
produire_documentation = function(
    uid = "JORFDOLE000054148224",
    sortie = file.path("/tmp", paste0("assembleer-documentation-", uid, ".pdf")),
    cache = tools::R_user_dir("assembleer", "cache"),
    ouvrir = TRUE,
    modele = system.file("modeles", "template.Rmd", package = "assembleer")) {
  if (length(uid) != 1L || is.na(uid) || !grepl("^JORFDOLE[0-9]+$", uid))
    stop("Identifiant DOLE invalide.", call. = FALSE)
  fichier = file.path(cache, "assembleer.duckdb")
  if (!file.exists(fichier)) stop("Base DuckDB absente.", call. = FALSE)
  con = DBI::dbConnect(duckdb::duckdb(), dbdir = fichier, read_only = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  if (!DBI::dbExistsTable(con, DBI::Id(schema = "dole", table = "dossiers")) ||
      !DBI::dbExistsTable(con, DBI::Id(schema = "dole", table = "liens")))
    stop("Corpus DOLE absent : executer importer_dole().", call. = FALSE)
  dossier = DBI::dbGetQuery(con,
    "SELECT uid, archive FROM dole.dossiers WHERE uid = ?", params = list(uid))
  if (!nrow(dossier)) stop("Dossier DOLE introuvable : ", uid, call. = FALSE)
  documents = DBI::dbGetQuery(con,
    "SELECT libelle, url FROM dole.liens WHERE dossier_uid = ? ORDER BY libelle, url",
    params = list(uid))
  documents = documents[!is.na(documents$url) & grepl("^https?://", documents$url), , drop = FALSE]
  documents$chambre = ifelse(grepl("(^https?://)(www\\.)?assemblee-nationale\\.fr/", documents$url),
                             "Assemblee nationale",
                      ifelse(grepl("(^https?://)(www\\.)?senat\\.fr/", documents$url),
                             "Senat", "Autre source"))
  documents = unique(documents[, c("chambre", "libelle", "url")])
  documents = documents[order(match(documents$chambre,
                      c("Assemblee nationale", "Senat", "Autre source")),
                      documents$libelle, documents$url), , drop = FALSE]
  esc = function(x) .echapper_latex(as.character(x))
  # Une URL est representee par un lien PDF cliquable, sans imprimer sa longueur.
  lien = function(url, n) {
    # Les URL viennent du corpus officiel ; \\detokenize neutralise les caracteres TeX.
    if (grepl("[{}]", url)) return(esc(url))
    paste0("\\href{\\detokenize{", url, "}}{Ouvrir le document}")
  }
  # Le sujet est extrait d'un libelle DOLE, sans texte explicatif ajoute.
  references = documents$libelle[
    !is.na(documents$libelle) &
      grepl("^Pour comprendre.*:", documents$libelle, ignore.case = TRUE)
  ]
  sujet = if (length(references)) {
    trimws(sub("^[^:]*:[[:space:]]*", "", references[[1L]]))
  } else {
    paste("Dossier legislatif", uid)
  }
  titre_sujet = paste0(
    "\\noindent\\fbox{\\parbox{0.94\\linewidth}{\\centering\\large\\bfseries ",
    esc(sujet), "}}"
  )
  sections = c(
    titre_sujet,
    paste0("\\noindent\\textbf{Identifiant DOLE :} ", esc(uid)),
    paste0("\\noindent\\textbf{Archive officielle :} ", esc(dossier$archive[[1L]])),
    paste0("\\noindent\\textbf{Documents references :} ", nrow(documents)),
    "\\section*{Inventaire des pieces officielles}",
    paste("Les documents ci-dessous proviennent des liens explicites du dossier",
          "DOLE de la DILA. L'ordre de presentation est par chambre et intitule,",
          "et ne constitue pas une chronologie certifiee.")
  )
  if (!nrow(documents)) {
    sections = c(sections, "Aucun lien documentaire dans ce dossier DOLE.")
  } else {
    for (chambre in unique(documents$chambre)) {
      sections = c(sections, paste0("\\subsection*{", esc(chambre), "}"))
      indices = which(documents$chambre == chambre)
      for (i in indices) {
        intitule = documents$libelle[[i]]
        if (is.na(intitule) || !nzchar(intitule)) intitule = "Document sans libelle"
        sections = c(sections, paste0("\\noindent ",
          "\\textbf{", esc(intitule), "}\\par\n",
          lien(documents$url[[i]], i), "\\par\n",
          "{\\footnotesize\\ttfamily\\url{", documents$url[[i]], "}}\\par\\medskip"))
      }
    }
  }
  sections = c(sections,
    "\\section*{Provenance et limites}",
    paste("Source : corpus officiel DOLE (Direction de l'information legale et administrative),",
          "stocke localement dans assembleer. Les intitules sont reproduits tels que",
          "presents dans la base. Aucune date n'est inferee, aucun document n'est",
          "attribue a un dossier sur la seule ressemblance de son titre."))
  chemin = .pdf_assembleer("Documentation officielle du dossier",
                           uid, paste(sections, collapse = "\n\n"),
                           sortie, modele = modele)
  if (isTRUE(ouvrir)) {
    commande = Sys.which("xdg-open")
    if (nzchar(commande)) system2(commande, shQuote(chemin), wait = FALSE)
  }
  invisible(chemin)
}
