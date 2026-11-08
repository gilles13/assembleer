#' Produire la cheatsheet HTML
#'
#' G\u00E9n\u00E8re une page HTML autonome sur le mod\u00E8le de la cheatsheet eduschool.
#' @param fichier Chemin du fichier HTML \u00E0 produire.
#' @param ouvrir Ouvrir le fichier dans le navigateur apr\u00E8s g\u00E9n\u00E9ration.
#' @return Chemin du fichier HTML, invisiblement.
#' @export
produire_cheatsheet = function(fichier = file.path(tempdir(), "assembleer-cheatsheet.html"),
                               ouvrir = TRUE) {
  modele = system.file("modeles", "cheatsheet.html", package = "assembleer")
  logo = system.file("assets", "logo_hexa.png", package = "assembleer")
  if (!nzchar(modele) || !nzchar(logo)) stop("Mod\u00e8le ou logo cheatsheet introuvable.", call. = FALSE)
  fichier = normalizePath(fichier, mustWork = FALSE)
  dir.create(dirname(fichier), recursive = TRUE, showWarnings = FALSE)
  contenu = paste(readLines(modele, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  uri = paste0("data:image/png;base64,", jsonlite::base64_enc(readBin(logo, "raw", n = file.size(logo))))
  contenu = sub("{{HEXA}}", uri, contenu, fixed = TRUE)
  writeLines(contenu, fichier, useBytes = TRUE)
  if (isTRUE(ouvrir)) utils::browseURL(fichier)
  invisible(fichier)
}
