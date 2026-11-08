#' Produire une fiche PDF d'un dossier legislatif local
#'
#' Les documents sont relies par leur identifiant officiel de dossier.
#' Aucun rapprochement thematique et aucun telechargement ne sont effectues.
#' @param uid Identifiant officiel du dossier legislatif.
#' @param sortie Chemin du PDF, dans /tmp par defaut.
#' @param cache Repertoire de la base DuckDB.
#' @param ouvrir Ouvrir le PDF apres production.
#' @param modele Modele R Markdown du package.
#' @return Chemin du PDF, invisiblement.
#' @export
produire_dossier = function(uid, sortie = file.path('/tmp', paste0('assembleer-dossier-', uid, '.pdf')),
                            cache = tools::R_user_dir('assembleer', 'cache'),
                            ouvrir = FALSE,
                            modele = system.file('modeles', 'template.Rmd', package = 'assembleer')) {
  if (!is.character(uid) || length(uid) != 1L || is.na(uid) ||
      !grepl('^[A-Za-z0-9_-]+$', uid))
    stop('uid doit etre un identifiant de dossier valide.', call. = FALSE)
  if (!is.character(sortie) || length(sortie) != 1L || is.na(sortie) ||
      !nzchar(sortie) || tolower(tools::file_ext(sortie)) != 'pdf')
    stop('sortie doit designer un fichier PDF.', call. = FALSE)
  if (!nzchar(modele) || !file.exists(modele))
    stop('Modele Rmd introuvable.', call. = FALSE)
  dir.create(tempdir(), recursive = TRUE, showWarnings = FALSE)
  documents = requete(
    "SELECT DISTINCT uid, titre, texte_ref FROM dossiers_legislatifs
     WHERE uid = ? ORDER BY texte_ref, titre", params = list(uid), cache = cache)
  if (!nrow(documents)) stop('Dossier introuvable dans la base locale : ', uid, call. = FALSE)
  titres = unique(trimws(as.character(documents$titre)))
  titres = titres[!is.na(titres) & nzchar(titres)]
  titre = if (length(titres)) titres[[1L]] else paste('Dossier', uid)
  refs = unique(trimws(as.character(documents$texte_ref)))
  refs = refs[!is.na(refs) & nzchar(refs)]
  refs = refs[grepl('^[A-Z][A-Z0-9]{9,}$', refs)]
  type_document = function(x) {
    if (grepl('^RAPP', x)) return('Rapport')
    if (grepl('^PION', x)) return('Proposition de loi')
    if (grepl('^PRJL', x)) return('Projet de loi')
    if (grepl('^ACIN', x)) return('Texte adopte en commission')
    if (grepl('^TA', x)) return('Texte adopte')
    'Document parlementaire'
  }
  tab = data.frame(nature = vapply(refs, type_document, character(1)),
                   reference = refs, stringsAsFactors = FALSE)
  # Seules les correspondances exactes au dossier sont retenues.
  amendements = requete(
    'SELECT uid, numero, titre, sort FROM amendements WHERE dossier_ref = ? ORDER BY numero, uid',
    params = list(uid), cache = cache)
  echapper = function(x) .echapper_latex(as.character(x))
  contenu = c(
    paste0("\\begin{center}\\Large\\bfseries ", echapper(titre), "\\par\\end{center}"),
    paste0("\\noindent\\textbf{Identifiant officiel :} ", echapper(uid), "\\par\\medskip"),
    "\\section*{Documents parlementaires associ\u00E9s}",
    if (nrow(tab)) {
      x = tab
      names(x) = c("Nature", "R\u00E9f\u00E9rence officielle")
      knitr::kable(x, format = "latex", booktabs = TRUE, longtable = TRUE)
    } else "Aucune r\u00E9f\u00E9rence de document compl\u00E8te dans la base locale.",
    "\\section*{Amendements formellement rattach\u00E9s}",
    if (nrow(amendements)) {
      x = amendements[, c("numero", "titre", "sort"), drop = FALSE]
      names(x) = c("Num\u00E9ro", "Intitul\u00E9", "Sort")
      knitr::kable(x, format = "latex", booktabs = TRUE, longtable = TRUE)
    } else "Aucun amendement import\u00E9 et rattach\u00E9 \u00E0 ce dossier dans la base locale.",
    "\\section*{D\u00E9bats et scrutins}",
    "Les rapprochements th\u00E9matiques ne prouvent pas un rattachement officiel au dossier."
  )
  chemin = .pdf_assembleer("Assembl\u00E9e nationale \u2014 Dossier l\u00E9gislatif",
                           uid, paste(contenu, collapse = "\n\n"), sortie, modele = modele)
  if (isTRUE(ouvrir)) {
    commande = Sys.which('xdg-open')
    if (nzchar(commande)) system2(commande, chemin, wait = FALSE)
  }
  invisible(chemin)
}
