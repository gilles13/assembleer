#' Fiche PDF d'une motion de censure
#'
#' Seuls les votes favorables sont recenses. Les effectifs actuels des groupes
#' ne sont pas des effectifs historiques : ils ne sont jamais utilises par defaut.
#' @param numero Numero du scrutin ou UID.
#' @param seuil Majorite absolue des membres composant l'Assemblee a cette date.
#'   Par defaut 289 pour une Assemblee de 577 membres.
#' @param fichier Chemin du fichier produit (PDF ou HTML).
#' @param format Format de sortie : auto, pdf ou html. En mode auto, HTML
#'   est utilise si pdflatex n'est pas disponible.
#' @param cache Repertoire de la base locale.
#' @param ouvrir Ouvrir le PDF apres generation.
#' @return Chemin du PDF, invisiblement.
#' @export
fiche_motion_censure = function(
    numero, seuil = 289L,
    fichier = NULL, format = c("auto", "pdf", "html"),
    cache = tools::R_user_dir("assembleer", "cache"), ouvrir = TRUE) {
  format = match.arg(format)
  if (format == "auto")
    format = if (nzchar(Sys.which("pdflatex"))) "pdf" else "html"
  if (format == "pdf" && !nzchar(Sys.which("pdflatex")))
    stop("pdflatex est absent : utiliser format = 'html'.", call. = FALSE)
  if (is.null(fichier))
    fichier = file.path(tempdir(), paste0("assembleer-motion-censure.", format))
  extension = tolower(tools::file_ext(fichier))
  if (extension != format)
    stop("L'extension de fichier doit correspondre au format choisi : .", format,
         call. = FALSE)
  s = scrutins(cache = cache)
  if (length(numero) != 1L || is.na(numero))
    stop("Fournir un numero ou UID de scrutin.", call. = FALSE)
  selection = if (grepl("^VTANR", as.character(numero)))
    as.character(s$uid) == as.character(numero) else
    as.character(s$numero) == as.character(numero)
  selection[is.na(selection)] = FALSE
  if (sum(selection) != 1L) stop("Scrutin introuvable ou ambigu.", call. = FALSE)
  scrutin = s[which(selection), , drop = FALSE]
  if (!identical(scrutin$type_vote[[1L]], "motion de censure"))
    stop("Ce scrutin n'est pas une motion de censure.", call. = FALSE)
  if (length(seuil) != 1L || is.na(seuil) || seuil < 1 || seuil != as.integer(seuil))
    stop("Seuil invalide.", call. = FALSE)

  v = votes_scrutin(scrutin$uid[[1L]], cache = cache)
  if (!all(c("groupe", "position") %in% names(v)))
    stop("Colonnes groupe/position absentes.", call. = FALSE)
  positions = as.character(v$position)
  autres = !is.na(positions) & !positions %in% c("pour", "contre", "abstention", "non_votant")
  if (any(autres)) stop("Positions inconnues dans les votes.", call. = FALSE)
  g = as.character(v$groupe[!is.na(positions) & positions == "pour"])
  g[is.na(g) | !nzchar(trimws(g))] = "Non renseigne"
  tab = as.data.frame(table(g), stringsAsFactors = FALSE)
  names(tab) = c("groupe", "pour")
  tab$pour = as.integer(tab$pour)
  if (sum(tab$pour) != scrutin$pour[[1L]])
    warning("Le total des votes nominatifs differe du total officiel.")

  effectifs = requete("SELECT o.libelle_abrege AS groupe, o.libelle AS nom_complet, e.total_groupe
                      FROM effectifs_groupes_scrutins e
                      JOIN organes o ON o.uid = e.groupe_ref
                      WHERE e.scrutin_uid = ?",
                      list(scrutin$uid[[1L]]), cache = cache)
  if (!nrow(effectifs))
    stop("Effectifs historiques absents : executer assembleer:::.importer_effectifs_groupes().", call. = FALSE)
  if (anyDuplicated(effectifs$groupe) || anyNA(effectifs$groupe) ||
      anyNA(effectifs$total_groupe) || any(effectifs$total_groupe < 0L))
    stop("Effectifs historiques incomplets ou incoherents.", call. = FALSE)
  absents = setdiff(tab$groupe, effectifs$groupe)
  if (length(absents)) stop("Groupes sans effectif : ", paste(absents, collapse = ", "), call. = FALSE)
  tab$total_groupe = as.integer(effectifs$total_groupe[match(tab$groupe, effectifs$groupe)])
  if (any(tab$pour > tab$total_groupe)) stop("Voix superieures a l'effectif historique.", call. = FALSE)
  manquants = effectifs[!effectifs$groupe %in% tab$groupe, , drop = FALSE]
  if (nrow(manquants))
    tab = rbind(tab, data.frame(groupe = as.character(manquants$groupe),
                              pour = 0L, total_groupe = as.integer(manquants$total_groupe)))
  tab = tab[order(-tab$pour, tab$groupe), , drop = FALSE]
  # Utiliser les noms officiels historiques, non les groupes actuels des deputes.
  noms = effectifs$nom_complet[match(tab$groupe, effectifs$groupe)]
  valides = !is.na(noms) & nzchar(trimws(noms)) & noms != tab$groupe
  tab$affichage = tab$groupe
  tab$affichage[valides] = paste0(noms[valides], " (", tab$groupe[valides], ")")
  tab$part = ifelse(is.na(tab$total_groupe) | tab$total_groupe == 0L,
                    "\u2014", sprintf("%.1f %%", 100 * tab$pour / tab$total_groupe))
  voix = as.integer(scrutin$pour[[1L]])
  manque = max(0L, as.integer(seuil) - voix)
  resultat = if (voix >= seuil) "ADOPTEE" else "REJETEE"

  # Normaliser les espaces et laisser grid gerer la coupure selon la largeur.
  titre = gsub("[[:space:]]+", " ", as.character(scrutin$titre[[1L]]))
  titre = trimws(titre)
  titre_lignes = strwrap(titre, width = 92L)
  if (!length(titre_lignes)) titre_lignes = "Libelle non renseigne"
  if (length(titre_lignes) > 7L)
    stop("Libelle trop long pour la mise en page actuelle.", call. = FALSE)
  # Le lien de scrutin est officiel ; la reference du texte est conservee telle quelle.
  # Le JSON du scrutin fournit dossierRef ; la table scrutins ne le stocke pas.
  archive = file.path(cache, "scrutins.json.zip")
  dossier_ref = NA_character_
  if (file.exists(archive)) {
    nom = paste0("json/", scrutin$uid[[1L]], ".json")
    if (nom %in% utils::unzip(archive, list = TRUE)$Name) {
      js = jsonlite::fromJSON(unz(archive, nom), simplifyVector = FALSE)
      dossier_ref = .valeur(js$scrutin$objet$dossierLegislatif$dossierRef)
    }
  }
  reference = NA_character_
  if (!is.na(dossier_ref) && nzchar(dossier_ref)) {
    refs = requete("SELECT DISTINCT texte_ref FROM dossiers_legislatifs WHERE uid = ?",
                   list(dossier_ref), cache = cache)
    if (nrow(refs)) reference = paste(unique(stats::na.omit(refs$texte_ref)), collapse = ", ")
  }
  url_scrutin = sprintf("https://www.assemblee-nationale.fr/dyn/17/scrutins/%s", scrutin$numero[[1L]])

  if (format == "html") {
    echapper = function(x) {
      x = as.character(x)
      x = gsub("&", "&amp;", x, fixed = TRUE)
      x = gsub("<", "&lt;", x, fixed = TRUE)
      x = gsub(">", "&gt;", x, fixed = TRUE)
      gsub('"', "&quot;", x, fixed = TRUE)
    }
    ligne_source = function(nom, valeur) {
      if (is.na(valeur) || !nzchar(valeur)) return(character())
      sprintf("<p><strong>%s :</strong> %s</p>", nom, echapper(valeur))
    }
    lignes = vapply(seq_len(nrow(tab)), function(i)
      sprintf("<tr><td>%s</td><td>%d</td><td>%d</td><td>%s</td></tr>",
              echapper(tab$affichage[[i]]), tab$pour[[i]],
              tab$total_groupe[[i]], echapper(tab$part[[i]])), character(1))
    total = sprintf("<tr class='total'><td>TOTAL</td><td>%d</td><td>%d</td><td>%.1f %%</td></tr>",
                    sum(tab$pour), sum(tab$total_groupe),
                    100 * sum(tab$pour) / sum(tab$total_groupe))
    progression = sprintf("%.1f", 100 * min(voix / seuil, 1))
    page = c(
      "<!doctype html><html lang='fr'><head><meta charset='UTF-8'>",
      "<meta name='viewport' content='width=device-width, initial-scale=1'>",
      "<title>Motion de censure</title>",
      "<style>body{font-family:system-ui,sans-serif;max-width:900px;margin:3em auto;padding:0 1.5em;color:#213547}h1,h2{color:#163d5c}header{border-bottom:2px solid #163d5c;margin-bottom:2em}header p{color:#667}blockquote{background:#eaf0f5;border-radius:9px;padding:1.2em;margin:1.5em 0}a{color:#245d8a}.barre{background:#e0e6ec;height:13px;border-radius:6px;overflow:hidden}.barre>div{background:#537fa9;height:100%}table{width:100%;border-collapse:collapse;margin-top:1.2em}th,td{padding:.8em .5em;border-bottom:1px solid #d7e0e7;text-align:right}th:first-child,td:first-child{text-align:left}.total{font-weight:bold}footer{color:#667;font-size:.85em;margin-top:2em}@media print{body{margin:1cm;max-width:none}a{color:inherit}}</style>",
      "</head><body><header><h1>Motion de censure</h1>",
      sprintf("<p>Scrutin n\u00b0 %s | %s</p></header>",
              echapper(scrutin$numero[[1L]]), echapper(scrutin$date[[1L]])),
      sprintf("<blockquote>%s</blockquote>", echapper(titre)),
      "<h2>Sources officielles</h2>",
      sprintf("<p><a href='%s'>Scrutin n\u00b0 %s \u2014 Assembl\u00e9e nationale</a></p>",
              echapper(url_scrutin), echapper(scrutin$numero[[1L]])),
      ligne_source("Dossier", dossier_ref),
      ligne_source("Texte de la motion", reference),
      sprintf("<h2>Motion %s</h2>", if (voix >= seuil) "adopt\u00e9e" else "rejet\u00e9e"),
      sprintf("<p><strong>%d voix favorables</strong> / %d voix n\u00e9cessaires</p>", voix, seuil),
      sprintf("<div class='barre'><div style='width:%s%%'></div></div>", progression),
      sprintf("<p>%s</p>", if (voix < seuil)
        sprintf("Il manquait %d voix pour adopter la motion.", manque)
        else "Le seuil requis a \u00e9t\u00e9 atteint."),
      "<p>Majorit\u00e9 absolue des membres de l'Assembl\u00e9e (289 sur 577 en configuration compl\u00e8te).</p>",
      "<h2>Voix favorables par groupe parlementaire</h2>",
      "<table><thead><tr><th>Groupe</th><th>Pour</th><th>Total groupe</th><th>Part</th></tr></thead><tbody>",
      lignes, total, "</tbody></table>",
      "<footer><p>Effectifs officiels des groupes \u00e0 la date du scrutin (DuckDB).</p>",
      "<p>Seuls les votes pour sont recens\u00e9s (Constitution, art. 49.2).</p>",
      "<p>Source : Assembl\u00e9e nationale \u2014 scrutins et votes.</p></footer></body></html>"
    )
    dir.create(dirname(fichier), recursive = TRUE, showWarnings = FALSE)
    writeLines(page, fichier, useBytes = TRUE)
    chemin = normalizePath(fichier)
    if (isTRUE(ouvrir)) {
      commande = Sys.which("xdg-open")
      if (nzchar(commande)) system2(commande, chemin, wait = FALSE)
    }
    return(invisible(chemin))
  }

  dir.create(dirname(fichier), recursive = TRUE, showWarnings = FALSE)
  grDevices::cairo_pdf(fichier, width = 8.27, height = 11.69, onefile = TRUE)
  ouvert = TRUE
  on.exit(if (ouvert) grDevices::dev.off(), add = TRUE)
  grid::grid.newpage()
  entete("Motion de censure", paste0("Scrutin n\u00b0 ", scrutin$numero[[1L]],
                                     "  |  ", scrutin$date[[1L]]))
  haut = .843
  hauteur = max(.09, .025 * length(titre_lignes) + .038)
  grid::grid.roundrect(x = .5, y = haut - hauteur / 2, width = .84,
                       height = hauteur, r = grid::unit(.12, "in"),
                       gp = grid::gpar(fill = "#EAF0F5", col = "#D0DEE8"))
  for (j in seq_along(titre_lignes))
    grid::grid.text(titre_lignes[[j]], x = .105,
                    y = haut - .028 - (j - 1L) * .025, just = "left",
                    gp = grid::gpar(fontsize = 9, col = "#163D5C"))
  y = haut - hauteur - .034
  grid::grid.text("SOURCES OFFICIELLES", x = .08, y = y, just = "left",
                  gp = grid::gpar(fontsize = 10, fontface = "bold", col = "#163D5C"))
  y = y - .026
  grid::grid.text(paste0("Scrutin n\u00b0 ", scrutin$numero[[1L]], " : ", url_scrutin),
                  x = .08, y = y, just = "left", gp = grid::gpar(fontsize = 7.7, col = "#245D8A"))
  if (!is.na(dossier_ref) && nzchar(dossier_ref)) {
    y = y - .021
    grid::grid.text(paste0("Dossier : ", dossier_ref), x = .08, y = y,
                    just = "left", gp = grid::gpar(fontsize = 8))
  }
  if (!is.na(reference) && nzchar(reference)) {
    y = y - .021
    grid::grid.text(paste0("Texte de la motion : ", reference), x = .08, y = y,
                    just = "left", gp = grid::gpar(fontsize = 8))
  }
  y = y - .046
  grid::grid.text(paste("MOTION", resultat), x = .08, y = y, just = "left",
                  gp = grid::gpar(fontsize = 15, fontface = "bold", col = "#163D5C"))
  y = y - .049
  grid::grid.text(sprintf("%d voix favorables", voix), x = .08, y = y,
                  just = "left", gp = grid::gpar(fontsize = 15, fontface = "bold"))
  grid::grid.text(sprintf("%d voix necessaires", seuil), x = .92, y = y,
                  just = "right", gp = grid::gpar(fontsize = 13, fontface = "bold"))
  y = y - .033
  grid::grid.rect(x = .5, y = y, width = .84, height = .012,
                  gp = grid::gpar(fill = "#E0E6EC", col = NA))
  grid::grid.rect(x = .08 + .84 * min(voix / seuil, 1) / 2, y = y,
                  width = .84 * min(voix / seuil, 1), height = .012,
                  gp = grid::gpar(fill = "#537FA9", col = NA))
  y = y - .035
  grid::grid.text(if (voix < seuil)
    sprintf("Il manquait %d voix pour adopter la motion.", manque) else
    "Le seuil requis a ete atteint.", x = .08, y = y, just = "left",
    gp = grid::gpar(fontsize = 10, fontface = "bold"))
  y = y - .025
  grid::grid.text("Majorite absolue des membres de l'Assemblee (289 sur 577 en configuration complete).",
                  x = .08, y = y, just = "left", gp = grid::gpar(fontsize = 8, col = "#666666"))
  y = y - .048
  grid::grid.text("Voix favorables par groupe parlementaire", x = .08, y = y,
                  just = "left", gp = grid::gpar(fontsize = 10, fontface = "bold"))
  y = y - .038
  xcols = c(.08, .66, .80, .92)
  entetes = c("Groupe", "Pour", "Total groupe", "Part")
  for (j in seq_along(entetes))
    grid::grid.text(entetes[[j]], x = xcols[[j]], y = y,
                    just = if (j == 1L) "left" else "right",
                    gp = grid::gpar(fontsize = 8.5, fontface = "bold"))
  y = y - .016
  grid::grid.lines(x = c(.08, .92), y = c(y, y), gp = grid::gpar(col = "#BAC8D2"))
  # Poursuivre le tableau sur une autre page si necessaire.
  nouvelle_page_table = function() {
    grid::grid.newpage()
    entete("Motion de censure", paste0("Scrutin n\u00b0 ", scrutin$numero[[1L]],
                                       "  |  Suite"))
    y = .80
    grid::grid.text("Voix favorables par groupe parlementaire (suite)",
                    x = .08, y = y, just = "left",
                    gp = grid::gpar(fontsize = 10, fontface = "bold"))
    y = y - .038
    for (j in seq_along(entetes))
      grid::grid.text(entetes[[j]], x = xcols[[j]], y = y,
                      just = if (j == 1L) "left" else "right",
                      gp = grid::gpar(fontsize = 8.5, fontface = "bold"))
    y = y - .016
    grid::grid.lines(x = c(.08, .92), y = c(y, y),
                     gp = grid::gpar(col = "#BAC8D2"))
    y
  }
  for (i in seq_len(nrow(tab))) {
    libelle = tab$affichage[[i]]
    # Deux lignes au maximum pour preserver les colonnes numeriques.
    lignes = strwrap(libelle, width = 63L)
    hauteur_ligne = .023 * max(1L, length(lignes)) + .009
    if (y - hauteur_ligne - .037 < .12) y = nouvelle_page_table()
    y = y - hauteur_ligne
    vals = c("", tab$pour[[i]],
             if (is.na(tab$total_groupe[[i]])) "\u2014" else tab$total_groupe[[i]],
             tab$part[[i]])
    for (k in seq_along(lignes))
      grid::grid.text(lignes[[k]], x = xcols[[1L]], y = y + .012 +
                        (length(lignes) - k) * .023, just = "left",
                      gp = grid::gpar(fontsize = 8))
    for (j in 2:length(vals))
      grid::grid.text(vals[[j]], x = xcols[[j]], y = y + .012,
                      just = if (j == 1L) "left" else "right",
                      gp = grid::gpar(fontsize = 8.5))
  }
  if (y - .037 < .12) y = nouvelle_page_table()
  y = y - .037
  vals = c("TOTAL", sum(tab$pour),
           if (all(!is.na(tab$total_groupe))) sum(tab$total_groupe) else "\u2014",
           if (all(!is.na(tab$total_groupe)) && sum(tab$total_groupe) > 0)
             sprintf("%.1f %%", 100 * sum(tab$pour) / sum(tab$total_groupe)) else "\u2014")
  for (j in seq_along(vals))
    grid::grid.text(vals[[j]], x = xcols[[j]], y = y,
                    just = if (j == 1L) "left" else "right",
                    gp = grid::gpar(fontsize = 9, fontface = "bold"))
  grid::grid.text("Effectifs officiels des groupes a la date du scrutin (DuckDB).",
    x = .08, y = .092, just = "left", gp = grid::gpar(fontsize = 8, col = "#666666"))
  grid::grid.text("Seuls les votes pour sont recenses (Constitution, art. 49.2).",
                  x = .08, y = .072, just = "left", gp = grid::gpar(fontsize = 8, col = "#666666"))
  grid::grid.text("Source : Assemblee nationale \u2014 scrutins et votes.",
                  x = .08, y = .052, just = "left", gp = grid::gpar(fontsize = 8, col = "#666666"))
  grDevices::dev.off()
  ouvert = FALSE

  # cairo_pdf ne produit pas d'annotations URI. Ajouter le lien avec
  # hyperref/pdfpages sans modifier le dessin ni la pagination de grid.
  latex = Sys.which("pdflatex")
  temporaire = tempfile("assembleer-pdf-")
  dir.create(temporaire)
  on.exit(unlink(temporaire, recursive = TRUE), add = TRUE)
  if (!file.copy(fichier, file.path(temporaire, "source.pdf")))
    stop("Impossible de preparer le PDF pour les liens.", call. = FALSE)
  # Position de la ligne du scrutin dans la page A4, en points PDF.
  y_lien = (haut - hauteur - .034 - .026) * 841.68 - 6
  tex = c(
    "\\documentclass[a4paper]{article}",
    "\\usepackage{pdfpages}",
    "\\usepackage{hyperref}",
    "\\usepackage{eso-pic}",
    "\\hypersetup{hidelinks}",
    "\\begin{document}",
    sprintf(paste0(
      "\\includepdf[pages=-,pagecommand={",
      "\\ifnum\\value{page}=1",
      "\\AddToShipoutPictureFG*{\\AtPageLowerLeft{",
      "\\put(48,%.2f){\\href{%s}{\\phantom{\\rule{475pt}{12pt}}}}}}",
      "\\fi}]{source.pdf}"), y_lien, url_scrutin),
    "\\end{document}"
  )
  writeLines(tex, file.path(temporaire, "liens.tex"), useBytes = TRUE)
  sortie = local({
    ancien_dossier = getwd()
    on.exit(setwd(ancien_dossier))
    setwd(temporaire)
    suppressWarnings(system2(latex,
      c("-interaction=nonstopmode", "-halt-on-error", "liens.tex"),
      stdout = TRUE, stderr = TRUE))
  })
  if (!file.exists(file.path(temporaire, "liens.pdf")) ||
      !is.null(attr(sortie, "status")))
    stop("Echec de l'ajout du lien PDF : ", paste(utils::tail(sortie, 8L), collapse = "\n"),
         call. = FALSE)
  if (!file.copy(file.path(temporaire, "liens.pdf"), fichier, overwrite = TRUE))
    stop("Impossible d'enregistrer le PDF avec son lien.", call. = FALSE)
  chemin = normalizePath(fichier)
  if (isTRUE(ouvrir)) {
    commande = Sys.which("xdg-open")
    if (nzchar(commande)) system2(commande, chemin, wait = FALSE)
  }
  invisible(chemin)
}
