# Modele PDF : une page de synthese, avec references des dossiers.
dessiner_bilan = function(bilan, semaine, entete_fn) {
  dossiers = bilan$dossiers
  scrutins = bilan$scrutins
  periode = sprintf("Du %s au %s", format(semaine, "%d/%m/%Y"),
                    format(semaine + 6L, "%d/%m/%Y"))
  couleur = "#163D5C"
  texte = function(x, y, taille = 10, gras = FALSE, col = "#222222") {
    grid::grid.text(x, x = .08, y = y, just = "left",
                    gp = grid::gpar(fontsize = taille,
                                    fontface = if (gras) "bold" else "plain", col = col))
  }
  ligne = function(x, y, largeur = 88L, taille = 10, gras = FALSE) {
    morceaux = strwrap(as.character(x), width = largeur)
    if (!length(morceaux)) morceaux = "Non renseigne"
    for (morceau in morceaux) {
      texte(morceau, y, taille = taille, gras = gras)
      y = y - .020
    }
    y
  }
  # Chaque dossier reste entier ; on cree une page avant qu'il ne deborde.
  nouvelle_page = function(premiere = FALSE) {
    grid::grid.newpage()
    entete_fn("Bilan hebdomadaire",
              paste("Assemblee nationale — Scrutins publics |", periode))
    if (premiere) {
      texte("L'activite de la semaine", .825, 13, TRUE, couleur)
      texte(sprintf("%d dossiers legislatifs  |  %d scrutins publics  |  %d adoptes  |  %d rejetes",
                    nrow(dossiers), nrow(scrutins),
                    sum(dossiers$adoptes), sum(dossiers$rejetes)), .785, 10)
      texte("Dossiers examines", .72, 12, TRUE, couleur)
      .68
    } else {
      texte("Dossiers examines (suite)", .825, 12, TRUE, couleur)
      .78
    }
  }
  pied_page = function() {
    texte("Les resultats portent sur les scrutins publics, et non sur l'adoption definitive des lois.",
          .085, 8, col = "#555555")
    texte("Source : donnees JSON officielles de l'Assemblee nationale, archivees localement.",
          .061, 8, col = "#555555")
  }
  y = nouvelle_page(premiere = TRUE)
  if (!nrow(dossiers)) {
    texte("Aucun scrutin public pour cette semaine.", y)
  } else {
    for (i in seq_len(nrow(dossiers))) {
      d = dossiers[i, , drop = FALSE]
      titre = if (is.na(d$titre)) "Dossier non renseigne" else d$titre
      lignes = strwrap(paste0(i, ". ", titre), width = 83L)
      # La hauteur inclut le titre, les chiffres, la reference et l'espacement.
      hauteur = length(lignes) * .020 + .078
      if (y - hauteur < .12) {
        pied_page()
        y = nouvelle_page()
      }
      y = ligne(paste0(i, ". ", titre), y, largeur = 83L, taille = 10, gras = TRUE)
      texte(sprintf("%d scrutins : %d adoptes, %d rejetes ; %d amendements, %d articles, %d ensembles",
                    d$scrutins, d$adoptes, d$rejetes,
                    d$amendements, d$articles, d$ensembles), y - .003, 8)
      y = y - .025
      ref = as.character(d$dossier_uid)
      if (length(ref) == 1L && !is.na(ref) && grepl("^DLR5L[0-9]+N[0-9]+$", ref)) {
        legislature = sub("^DLR5L([0-9]+)N[0-9]+$", "\\1", ref)
        url = paste0("https://www.assemblee-nationale.fr/dyn/", legislature,
                     "/dossiers/", ref)
        texte(paste("Dossier", ref, "—", url), y, 7, col = couleur)
      } else {
        texte(paste("Dossier :", if (length(ref) && !is.na(ref)) ref else "non renseigne"),
              y, 8, col = "#555555")
      }
      y = y - .053
    }
  }
  pied_page()
}
