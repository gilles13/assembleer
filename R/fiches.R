
.groupes_deputes = function(x, cache) {
  noms = names(.nettoyer_noms(x))
  candidats = which(grepl("(^|_)groupe(_|$)", noms))
  if (!length(candidats)) {
    stop("La table deputes ne contient pas de colonne de groupe.", call. = FALSE)
  }
  # Privilegier un intitule complet s'il est disponible.
  score = grepl("libelle|nom|complet|intitule", noms[candidats]) * 3 -
    grepl("sigle|abrege|code", noms[candidats]) * 2 -
    grepl("ancien|histor", noms[candidats]) * 5
  colonne = candidats[which.max(score)]
  g = trimws(as.character(x[[colonne]]))
  # Les libelles et sigles sont ceux des organes officiels AMO40.
  sigles = rep(NA_character_, length(g))
  org = groupes(cache = cache)
  if (nrow(org)) {
    org = org[!is.na(org$libelle) & nzchar(trimws(org$libelle)), , drop = FALSE]
    for (cle in c("uid", "libelle_abrege", "libelle")) {
      correspondance = match(tolower(g), tolower(trimws(as.character(org[[cle]]))))
      trouve = !is.na(correspondance)
      g[trouve] = org$libelle[correspondance[trouve]]
      sigles[trouve] = org$libelle_abrege[correspondance[trouve]]
    }
  }
  valides = !is.na(sigles) & nzchar(trimws(sigles)) &
    tolower(trimws(sigles)) != tolower(trimws(g))
  g_affiche = g
  g_affiche[valides] = paste0(g[valides], " (", sigles[valides], ")")
  g[is.na(g) | !nzchar(g)] = "Non renseign\u00e9"
  g_affiche
}

#' Fiche PDF de composition de l'Assemblee
#'
#' Produit un document sobre a partir de la table locale des deputes.
#' La colonne de groupe doit etre presente dans le CSV officiel importe.
#' Aucun acces reseau n'est effectue.
#' @param fichier Chemin du PDF a produire.
#' @param cache Repertoire local de la base.
#' @param ouvrir Ouvrir le PDF apres generation (Linux avec xdg-open).
#' @return Chemin du PDF, invisiblement.
#' @export
fiche_composition = function(fichier = file.path(tempdir(), "assembleer-composition.pdf"),
                              cache = tools::R_user_dir("assembleer", "cache"), ouvrir = TRUE) {
  x = deputes(cache = cache)
  if (!nrow(x)) stop("Aucun depute : executer actualiser(sources = 'deputes')", call. = FALSE)
  g_affiche = .groupes_deputes(x, cache)
  tab = sort(table(g_affiche), decreasing = TRUE)
  n = sum(tab)
  vacants = 577L - n
  if (vacants < 0L) stop("Plus de 577 lignes de deputes : verifier les doublons.", call. = FALSE)
  resultat = data.frame(groupe = names(tab), deputes = as.integer(tab),
                        part = sprintf("%.1f %%", 100 * as.numeric(tab) / n))
  dir.create(dirname(fichier), recursive = TRUE, showWarnings = FALSE)
  grDevices::cairo_pdf(fichier, width = 8.27, height = 11.69, onefile = TRUE)
  on.exit(grDevices::dev.off(), add = TRUE)
  lignes_par_page = 29L
  pages = split(seq_len(nrow(resultat)), ceiling(seq_len(nrow(resultat)) / lignes_par_page))
  for (p in seq_along(pages)) {
    grid::grid.newpage()
    entete("Composition de l\u2019Assembl\u00e9e nationale",
           paste0("Source : table locale des d\u00e9put\u00e9s  |  \u00c9dition : ", Sys.Date()))
    grid::grid.text(sprintf("Total : %d d\u00e9put\u00e9s en exercice \u2014 %d si\u00e8ge%s vacant%s sur 577",
                            n, vacants, if (vacants > 1L) "s" else "",
                            if (vacants > 1L) "s" else ""), x = .08, y = .835,
                    just = "left", gp = grid::gpar(fontsize = 12))
    grid::grid.text("Formation politique", x = .08, y = .795, just = "left", gp = grid::gpar(fontface = "bold"))
    grid::grid.text("Effectif", x = .77, y = .795, just = "right", gp = grid::gpar(fontface = "bold"))
    grid::grid.text("Part", x = .92, y = .795, just = "right", gp = grid::gpar(fontface = "bold"))
    for (j in seq_along(pages[[p]])) {
      i = pages[[p]][[j]]
      y = .765 - (j - 1) * .023
      grid::grid.text(resultat$groupe[[i]], x = .08, y = y, just = "left",
                      gp = grid::gpar(fontsize = 9))
      grid::grid.text(as.character(resultat$deputes[[i]]), x = .77, y = y, just = "right",
                      gp = grid::gpar(fontsize = 10))
      grid::grid.text(resultat$part[[i]], x = .92, y = y, just = "right",
                      gp = grid::gpar(fontsize = 10))
    }
    grid::grid.text(sprintf("Page %d / %d", p, length(pages)), x = .92, y = .045,
                    just = "right", gp = grid::gpar(fontsize = 8, col = "#777777"))
  }
  grDevices::dev.off()
  on.exit(NULL, add = FALSE)
  chemin = normalizePath(fichier)
  if (isTRUE(ouvrir)) {
    commande = Sys.which("xdg-open")
    if (nzchar(commande)) system2(commande, chemin, wait = FALSE)
  }
  invisible(chemin)
}

#' Liste PDF detaillee des deputes par groupe parlementaire
#'
#' Produit une fiche a partir des colonnes disponibles dans le CSV officiel :
#' identifiant, prenom, nom, region, departement, circonscription et profession.
#' Un sigle de groupe peut etre fourni pour limiter la liste.
#' @param formation Sigle du groupe (par exemple "RN"), ou NULL pour tous.
#' @param fichier Chemin du PDF a produire.
#' @param cache Repertoire local de la base.
#' @param ouvrir Ouvrir automatiquement le PDF.
#' @return Chemin du PDF, invisiblement.
#' @export
fiche_deputes_groupes = function(
    formation = NULL,
    fichier = file.path(tempdir(), "assembleer-deputes-groupes.pdf"),
    cache = tools::R_user_dir("assembleer", "cache"), ouvrir = TRUE) {
  x = deputes(cache = cache)
  if (!nrow(x)) stop("Aucun depute : executer actualiser(sources = 'deputes')", call. = FALSE)

  colonnes = c("identifiant", "prenom", "nom", "region", "departement",
               "numero_de_circonscription", "profession",
               "groupe_politique_complet", "groupe_politique_abrege")
  absentes = setdiff(colonnes, names(x))
  if (length(absentes))
    stop("Colonnes absentes : ", paste(absentes, collapse = ", "), call. = FALSE)

  if (!is.null(formation)) {
    if (!is.character(formation) || length(formation) != 1L ||
        is.na(formation) || !nzchar(trimws(formation)))
      stop("'formation' doit etre un sigle non vide, ou NULL.", call. = FALSE)
    selection = !is.na(x$groupe_politique_abrege) &
      toupper(trimws(x$groupe_politique_abrege)) == toupper(trimws(formation))
    if (!any(selection))
      stop("Aucun depute pour la formation : ", formation, call. = FALSE)
    x = x[selection, , drop = FALSE]
  }

  # Utiliser les libelles du CSV des deputes : aucune jointure supplementaire.
  groupe = paste0(x$groupe_politique_complet, " (",
                  x$groupe_politique_abrege, ")")
  ord = order(groupe, x$nom, x$prenom, na.last = TRUE)
  x = x[ord, , drop = FALSE]
  groupe = groupe[ord]

  propre = function(z) {
    z = as.character(z)
    z[is.na(z) | !nzchar(trimws(z))] = "Non renseign\u00e9"
    trimws(z)
  }
  champs = c("identifiant", "prenom", "nom", "departement",
             "numero_de_circonscription", "profession")
  titres = c("Identifiant", "Prénom", "Nom", "Département", "Circ.", "Profession")
  tableaux = lapply(split(seq_len(nrow(x)), factor(groupe, levels = unique(groupe))),
                    function(indices) {
    donnees = x[indices, champs, drop = FALSE]
    donnees[] = lapply(donnees, propre)
    names(donnees) = titres
    donnees
  })

  modele = system.file("modeles", "deputes_groupes.Rmd", package = "assembleer")
  if (!nzchar(modele)) modele = file.path("inst", "modeles", "deputes_groupes.Rmd")
  if (!file.exists(modele)) stop("Modele R Markdown introuvable.", call. = FALSE)
  logo = system.file("assets", "logo_hexa.png", package = "assembleer")
  if (!nzchar(logo)) logo = file.path("inst", "assets", "logo_hexa.png")
  if (!file.exists(logo)) logo = ""

  dir.create(dirname(fichier), recursive = TRUE, showWarnings = FALSE)
  fichier = normalizePath(fichier, mustWork = FALSE)
  message(sprintf("Députés : %d lignes, %d groupes ; compilation PDF...",
                  nrow(x), length(tableaux)))
  rendu = rmarkdown::render(
    input = modele,
    output_file = basename(fichier),
    output_dir = dirname(fichier),
    params = list(tableaux = tableaux, logo = normalizePath(logo, mustWork = FALSE),
                  date = as.character(Sys.Date())),
    envir = new.env(parent = baseenv()), quiet = TRUE
  )
  message("PDF généré : ", rendu)
  if (isTRUE(ouvrir)) {
    commande = Sys.which("xdg-open")
    if (nzchar(commande)) system2(commande, rendu, wait = FALSE)
  }
  invisible(normalizePath(rendu))
}
