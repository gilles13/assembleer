#' Produire la cheatsheet HTML
#'
#' Génère une page HTML autonome sur le modèle de la cheatsheet eduschool.
#' @param fichier Chemin du fichier HTML à produire.
#' @param ouvrir Ouvrir le fichier dans le navigateur après génération.
#' @return Chemin du fichier HTML, invisiblement.
#' @export
produire_cheatsheet = function(fichier = file.path(tempdir(), "assembleer-cheatsheet.html"),
                               ouvrir = TRUE) {
  modele = system.file("modeles", "cheatsheet.html", package = "assembleer")
  logo = system.file("assets", "logo_hexa.png", package = "assembleer")
  if (!nzchar(modele) || !nzchar(logo)) stop("Modèle ou logo cheatsheet introuvable.", call. = FALSE)
  fichier = normalizePath(fichier, mustWork = FALSE)
  dir.create(dirname(fichier), recursive = TRUE, showWarnings = FALSE)
  contenu = paste(readLines(modele, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  uri = paste0("data:image/png;base64,", jsonlite::base64_enc(readBin(logo, "raw", n = file.size(logo))))
  contenu = sub("{{HEXA}}", uri, contenu, fixed = TRUE)
  writeLines(contenu, fichier, useBytes = TRUE)
  if (isTRUE(ouvrir)) utils::browseURL(fichier)
  invisible(fichier)
}
