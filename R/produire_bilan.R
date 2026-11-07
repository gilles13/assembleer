#' Produire un bilan hebdomadaire PDF
#'
#' Produit un PDF a partir du bilan local des scrutins publics. Aucun acces reseau.
#' Les resultats portent sur les scrutins, pas sur l'adoption definitive des lois.
#' @param semaine Lundi de la semaine a presenter.
#' @param fichier Chemin du PDF genere.
#' @param cache Repertoire du cache assembleer.
#' @param ouvrir Ouvrir le PDF apres generation.
#' @return Chemin du PDF, invisiblement.
#' @usage produire_bilan(semaine,
#'   fichier = file.path(tempdir(), paste0("assembleer-bilan-",
#'     as.Date(semaine), ".pdf")),
#'   cache = tools::R_user_dir("assembleer", "cache"),
#'   ouvrir = TRUE)
#' @export
produire_bilan = function(semaine,
    fichier = file.path(tempdir(), paste0("assembleer-bilan-", as.Date(semaine), ".pdf")),
    cache = tools::R_user_dir("assembleer", "cache"), ouvrir = TRUE) {
  bilan = bilan_hebdomadaire(semaine, cache = cache)
  modele = system.file("modeles", "bilan_hebdomadaire.R", package = "assembleer")
  if (!nzchar(modele)) modele = file.path("inst", "modeles", "bilan_hebdomadaire.R")
  if (!file.exists(modele)) stop("Modele de bilan introuvable.", call. = FALSE)
  environnement = new.env(parent = baseenv())
  sys.source(modele, envir = environnement)
  dir.create(dirname(fichier), recursive = TRUE, showWarnings = FALSE)
  grDevices::cairo_pdf(fichier, width = 8.27, height = 11.69, onefile = TRUE)
  ouvert = TRUE
  on.exit(if (ouvert) grDevices::dev.off(), add = TRUE)
  environnement$dessiner_bilan(bilan, as.Date(semaine), entete)
  grDevices::dev.off()
  ouvert = FALSE
  chemin = normalizePath(fichier)
  if (isTRUE(ouvrir)) {
    commande = Sys.which("xdg-open")
    if (nzchar(commande)) system2(commande, chemin, wait = FALSE)
  }
  invisible(chemin)
}
