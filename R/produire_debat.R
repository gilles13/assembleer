# Production d'un PDF a partir des paragraphes des debats deja importes.

#' Produire le PDF des echanges d'un point de debat
#'
#' Inclut le point selectionne et tous ses sous-points, sans modifier
#' l'ordre des paragraphes ni regrouper les interventions.
#' @param fichier Chemin du compte rendu dans l'archive XML importee.
#' @param id_syceron Identifiant du point de debat.
#' @param sortie Chemin du PDF a produire, dans /tmp par defaut.
#' @param cache Repertoire de la base DuckDB assembleer.
#' @param ouvrir Ouvrir le PDF apres generation.
#' @param modele Fichier Rmd du modele, par defaut celui du package.
#'   La date de la seance provient des reunions officielles deja importees.
#' @return Chemin du PDF, invisiblement.
#' @export
produire_debat = function(
    fichier = "xml/compteRendu/CRSANR5L17S2025E1N001.xml",
    id_syceron = "3827580",
    sortie = file.path("/tmp", paste0("assembleer-debat-", id_syceron, ".pdf")),
    cache = tools::R_user_dir("assembleer", "cache"), ouvrir = FALSE,
    modele = system.file("modeles", "template.Rmd", package = "assembleer")) {
  dir.create(tempdir(), recursive = TRUE, showWarnings = FALSE)
  sql = "
    WITH RECURSIVE descendants AS (
      SELECT fichier, id_syceron FROM debats_points
      WHERE fichier = ? AND id_syceron = ?
      UNION
      SELECT p.fichier, p.id_syceron FROM debats_points p
      JOIN descendants d ON p.fichier = d.fichier
                        AND p.parent_id_syceron = d.id_syceron
    )
    SELECT p.position, p.id_acteur, p.orateurs_xml, p.texte
    FROM debats_paragraphes p
    JOIN descendants d ON p.fichier = d.fichier
                      AND p.point_id_syceron = d.id_syceron
    ORDER BY p.position
  "
  if (!nzchar(modele) || !file.exists(modele))
    stop("Modele Rmd introuvable.", call. = FALSE)
  d = requete(sql, params = list(fichier, as.character(id_syceron)), cache = cache)
  if (!nrow(d)) stop("Aucun paragraphe pour ce point.", call. = FALSE)

  nom_orateur = function(x) {
    if (is.na(x) || !nzchar(x)) return(NA_character_)
    doc = tryCatch(xml2::read_xml(x), error = function(e) NULL)
    if (is.null(doc)) return(NA_character_)
    noeud = xml2::xml_find_first(doc, ".//*[local-name()='nom']")
    if (inherits(noeud, "xml_missing")) return(NA_character_)
    nom = trimws(xml2::xml_text(noeud))
    if (nzchar(nom)) nom else NA_character_
  }
  d$orateur = vapply(d$orateurs_xml, nom_orateur, character(1))

  # Les valeurs sont echappees avant insertion dans le flux LaTeX.
  latex = function(x) {
    if (is.na(x)) return("")
    x = gsub("\u00a0", " ", x, fixed = TRUE)
    x = gsub("\u202f", " ", x, fixed = TRUE)
    caracteres = strsplit(x, "", fixed = TRUE)[[1]]
    speciaux = c(
      "\\" = "\\textbackslash{}",
      "{" = "\\{", "}" = "\\}",
      "#" = "\\#", "$" = "\\$", "%" = "\\%",
      "&" = "\\&", "_" = "\\_",
      "~" = "\\textasciitilde{}", "^" = "\\textasciicircum{}"
    )
    indices = match(caracteres, names(speciaux))
    caracteres[!is.na(indices)] = unname(speciaux[indices[!is.na(indices)]])
    paste0(caracteres, collapse = "")
  }
  info = requete("SELECT titre FROM debats_points WHERE fichier = ? AND id_syceron = ? LIMIT 1",
                 params = list(fichier, as.character(id_syceron)), cache = cache)
  titre = if (nrow(info) && !is.na(info$titre[[1L]]) && nzchar(trimws(info$titre[[1L]])))
    info$titre[[1L]] else paste("D\u00e9bat", id_syceron)
  # Sujet de niveau 1 precedent le point selectionne dans la meme seance.
  # Le titre de section (Presentation, Discussion generale...) reste distinct.
  sujet_info = requete(
    paste0("SELECT p.titre FROM debats_points p ",
      "WHERE p.fichier = ? AND p.position <= ",
      "(SELECT position FROM debats_points WHERE fichier = ? AND id_syceron = ? LIMIT 1) ",
      "AND json_extract_string(p.attributs_json, '$.nivpoint') = '1' ",
      "AND p.titre IS NOT NULL ORDER BY p.position DESC LIMIT 1"),
    params = list(fichier, fichier, as.character(id_syceron)), cache = cache)
  sujet = if (nrow(sujet_info) && nzchar(trimws(sujet_info$titre[[1L]])))
    sujet_info$titre[[1L]] else titre
  # Date officielle : la reunion est reliee au compte rendu par seance_ref.
  seance = requete(
    "SELECT r.debut FROM debats_seances s LEFT JOIN reunions r ON r.uid = s.seance_ref WHERE s.fichier = ? LIMIT 1",
    params = list(fichier), cache = cache)
  debut = if (nrow(seance)) seance$debut[[1L]] else NA_character_
  if (is.null(debut) || is.na(debut) || !nzchar(debut)) {
    date_seance = "Date de seance non renseignee"
  } else {
    jour = as.Date(substr(debut, 1L, 10L))
    mois = c("janvier", "fevrier", "mars", "avril", "mai", "juin",
             "juillet", "aout", "septembre", "octobre", "novembre", "decembre")
    date_seance = if (is.na(jour)) "Date de seance non renseignee" else
      sprintf("%d %s %d", as.integer(format(jour, "%d")),
              mois[as.integer(format(jour, "%m"))], as.integer(format(jour, "%Y")))
  }

  # Rattachement institutionnel valable le jour de la seance.
  # Une fonction ministerielle prime sur un ancien groupe parlementaire.
  d$rattachement = rep(NA_character_, nrow(d))
  if (!is.null(debut) && !is.na(debut) && nzchar(debut)) {
    date_iso = substr(debut, 1L, 10L)
    rattachements = requete(paste0(
      "SELECT m.acteur_uid, m.type_organe, m.qualite, ",
      "o.libelle, o.libelle_abrege, m.date_debut, m.uid ",
      "FROM mandats m JOIN mandats_organes mo ON mo.mandat_uid = m.uid ",
      "JOIN organes o ON o.uid = mo.organe_uid ",
      "WHERE m.type_organe IN ('GP', 'MINISTERE') ",
      "AND m.acteur_uid IN ",
      "(SELECT DISTINCT id_acteur FROM debats_paragraphes WHERE fichier = ?) ",
      "AND m.date_debut <= CAST(? AS DATE) ",
      "AND (m.date_fin IS NULL OR m.date_fin >= CAST(? AS DATE)) ",
      "ORDER BY m.acteur_uid, ",
      "CASE WHEN m.type_organe = 'MINISTERE' AND ",
      "LOWER(COALESCE(m.qualite, '')) <> 'en mission' THEN 0 ",
      "WHEN m.type_organe = 'GP' THEN 1 ELSE 2 END, ",
      "m.date_debut DESC, m.uid DESC"),
      params = list(fichier, date_iso, date_iso), cache = cache)
    rattachements = rattachements[
      !(rattachements$type_organe == 'MINISTERE' &
          tolower(ifelse(is.na(rattachements$qualite), '',
                         rattachements$qualite)) == 'en mission'), , drop = FALSE]
    rattachements = rattachements[!duplicated(rattachements$acteur_uid), , drop = FALSE]
    etiquette = vapply(seq_len(nrow(rattachements)), function(i) {
      r = rattachements[i, , drop = FALSE]
      if (r$type_organe == 'GP') return(r$libelle_abrege[[1L]])
      qualite = r$qualite[[1L]]
      organe = r$libelle[[1L]]
      if (is.na(qualite) || !nzchar(trimws(qualite))) qualite = 'Membre du gouvernement'
      if (is.na(organe) || !nzchar(trimws(organe))) return(qualite)
      paste0(qualite, ' \u2014 ', organe)
    }, character(1))
    d$rattachement = etiquette[match(d$id_acteur, rattachements$acteur_uid)]
  }
  contenu = character()
  for (i in seq_len(nrow(d))) {
    nom = d$orateur[i]
    txt = d$texte[i]
    if (!is.na(nom)) contenu = c(contenu,
      paste0("\\noindent\\textbf{", latex(nom),
        if (!is.na(d$rattachement[i]) && nzchar(d$rattachement[i]))
          paste0(" (", latex(d$rattachement[i]), ")") else "", "}\\par"))
    if (!is.na(txt) && nzchar(trimws(txt))) contenu = c(contenu,
      paste0("\\noindent ", latex(txt), "\\par"))
    contenu = c(contenu, "")
  }
  chemin = .pdf_assembleer(
    titre = "Assembl\u00E9e nationale \u2014 D\u00E9bats", sous_titre = date_seance,
    contenu = paste0(
      "\\noindent\\begingroup\\setlength{\\fboxsep}{10pt}",
      "\\fcolorbox{blue!50!black}{blue!7}{\\parbox{0.91\\linewidth}{",
      "\\centering\\Large\\bfseries ", latex(sujet), "}}\\endgroup\\par\\medskip\n",
      "\\begin{center}\\large\\bfseries ", latex(titre),
      "\\par\\end{center}\\medskip\n",
      "\\noindent\\textbf{Date :} ", latex(date_seance),
      "\\quad\\textbf{S\u00E9ance :} ", latex(basename(fichier)),
      "\\quad\\textbf{Point :} ", latex(as.character(id_syceron)),
      "\\par\\medskip\n", paste(contenu, collapse = "\n")),
    sortie = sortie, modele = modele)
  if (isTRUE(ouvrir)) {
    commande = Sys.which("xdg-open")
    if (nzchar(commande)) system2(commande, chemin, wait = FALSE)
  }
  invisible(chemin)
}
