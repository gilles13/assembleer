# Moteur commun des documents PDF R Markdown.
.pdf_assembleer = function(titre, sous_titre = "", contenu, sortie, modele = NULL) {
  if (is.null(modele)) modele = system.file("modeles", "template.Rmd", package = "assembleer")
  if (!nzchar(modele)) modele = file.path("inst", "modeles", "template.Rmd")
  if (!file.exists(modele)) stop("Modele PDF introuvable.", call. = FALSE)
  logo = system.file("assets", "logo_hexa.png", package = "assembleer")
  if (!nzchar(logo)) logo = file.path("inst", "assets", "logo_hexa.png")
  if (!file.exists(logo)) stop("Logo hexagonal introuvable.", call. = FALSE)
  dir.create(dirname(sortie), recursive = TRUE, showWarnings = FALSE)
  sortie = normalizePath(sortie, mustWork = FALSE)
  rmarkdown::render(
    input = modele, output_file = basename(sortie), output_dir = dirname(sortie),
    params = list(titre = titre, sous_titre = sous_titre,
                  logo = normalizePath(logo, winslash = "/", mustWork = TRUE),
                  contenu = contenu),
    envir = new.env(parent = globalenv()), quiet = TRUE)
  normalizePath(sortie, mustWork = TRUE)
}

# Afficher le chemin dans tous les environnements, meme sans application graphique.
.ouvrir_pdf = function(chemin, ouvrir = TRUE) {
  chemin = normalizePath(chemin, mustWork = TRUE)
  message("PDF produit : ", chemin)
  if (!isTRUE(ouvrir)) return(invisible(chemin))
  commande = Sys.which("xdg-open")
  if (!nzchar(commande)) commande = Sys.which("gio")
  if (nzchar(commande)) {
    arguments = if (basename(commande) == "gio") c("open", shQuote(chemin)) else shQuote(chemin)
    invisible(system2(commande, arguments, wait = FALSE))
  } else {
    message("Aucune application PDF locale disponible. Recuperer le fichier : ", chemin)
  }
  invisible(chemin)
}
