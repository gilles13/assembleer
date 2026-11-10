# Importation des amendements depuis l'archive officielle.
# Transaction geree par actualiser() : une erreur annule toutes les insertions.
.importer_amendements = function(con, archive, journal) {
  fichiers_traites = 0L
  lignes_importees = 0L
  # Extraction unique ; DuckDB lit ensuite explicitement 500 fichiers par lot.
  inventaire = zip::zip_list(archive)
  noms = inventaire$filename[grepl("\\.json$", inventaire$filename, ignore.case = TRUE)]
  if (!length(noms) || anyDuplicated(noms) ||
      any(grepl("(^/|(^|/)\\.\\.(/|$))", noms)))
    stop("Archive d'amendements inattendue.")
  total = length(noms)
  taille_lot = 500L
  nombre_lots = as.integer(ceiling(total / taille_lot))
  journal("amendements", format(total, big.mark = " "),
          " JSON ; traitement par ", nombre_lots,
          " lots de ", taille_lot, " maximum.")
  dossier = tempfile("assembleer-amendements-")
  dir.create(dossier)
  # Lecture vectorisee par DuckDB : pas de parsing JSON dans R.
  debut = Sys.time()
  tryCatch({
    statut = system2("unzip", c("-oq", shQuote(archive), "-d", shQuote(dossier)))
    if (!identical(as.integer(statut), 0L)) stop("Echec de l'extraction ZIP des amendements.")
    if (any(!file.exists(file.path(dossier, noms)))) stop("Extraction incomplete des amendements.")
    journal("amendements", "Extraction terminee en ", round(as.numeric(difftime(Sys.time(), debut, units = "secs")), 1), " s")
    DBI::dbExecute(con, "CREATE TABLE IF NOT EXISTS fichiers_uid (source VARCHAR, chemin VARCHAR, uid VARCHAR, table_cible VARCHAR, PRIMARY KEY(source, chemin))")
    DBI::dbExecute(con, "DELETE FROM amendements")
    DBI::dbExecute(con, "DELETE FROM fichiers_uid WHERE source = 'amendements'")
    DBI::dbExecute(con, "DELETE FROM fichiers WHERE source = 'amendements'")
    for (j in seq_len(nombre_lots)) {
      indices = seq.int((j - 1L) * taille_lot + 1L, min(j * taille_lot, total))
      lot = noms[indices]
      chemins = file.path(dossier, lot)
      t1 = Sys.time()
      motif = paste0("[", paste(as.character(DBI::dbQuoteString(con, chemins)), collapse = ", "), "]")
      prefixe = DBI::dbQuoteString(con, paste0(normalizePath(dossier), "/"))
      DBI::dbExecute(con, paste0(
        "CREATE OR REPLACE TEMP TABLE am_lot AS SELECT ",
        "replace(filename, ", prefixe, ", '') AS chemin, ",
        "json_extract(content, '$.amendement') AS a FROM read_text(", motif, ")"))
      DBI::dbExecute(con, paste0(
        "CREATE OR REPLACE TEMP TABLE am_lignes AS SELECT chemin, ",
        "json_extract_string(a, '$.uid') AS uid, ",
        "json_extract_string(a, '$.identification.numeroLong') AS numero, ",
        "try_cast(json_extract_string(a, '$.legislature') AS INTEGER) AS legislature, ",
        "json_extract_string(a, '$.corps.cartouche.designationArticle') AS titre, ",
        "coalesce(json_extract_string(a, '$.corps.contenuAuteur.dispositif.texte'), ",
        "json_extract_string(a, '$.corps.contenuAuteur.dispositif.contenu'), ",
        "json_extract_string(a, '$.corps.contenuAuteur.dispositif.valeur'), ",
        "json_extract_string(a, '$.corps.contenuAuteur.dispositif'), ",
        "json_extract_string(a, '$.corps.dispositif.texte'), ",
        "json_extract_string(a, '$.corps.dispositif')) AS dispositif, ",
        "coalesce(json_extract_string(a, '$.corps.contenuAuteur.exposeSommaire.texte'), ",
        "json_extract_string(a, '$.corps.contenuAuteur.exposeSommaire.contenu'), ",
        "json_extract_string(a, '$.corps.contenuAuteur.exposeSommaire.valeur'), ",
        "json_extract_string(a, '$.corps.contenuAuteur.exposeSommaire'), ",
        "json_extract_string(a, '$.corps.exposeSommaire.texte'), ",
        "json_extract_string(a, '$.corps.exposeSommaire')) AS expose, ",
        "json_extract_string(a, '$.cycleDeVie.sort') AS sort, ",
        "json_extract_string(a, '$.dossierLegislatifRef') AS dossier_ref, ",
        "json_extract_string(a, '$.texteLegislatifRef') AS texte_ref ",
        "FROM am_lot WHERE a IS NOT NULL"))
      DBI::dbExecute(con, paste0(
        "INSERT INTO amendements SELECT uid, numero, legislature, titre, dispositif, expose, ",
        "sort, dossier_ref, texte_ref FROM am_lignes WHERE uid IS NOT NULL AND uid <> ''"))
      DBI::dbExecute(con, paste0(
        "INSERT INTO fichiers_uid SELECT 'amendements', chemin, uid, 'amendements' ",
        "FROM am_lignes WHERE uid IS NOT NULL AND uid <> ''"))
      DBI::dbAppendTable(con, "fichiers", data.frame(
        source = "amendements", chemin = lot,
        crc = as.character(inventaire$crc32[indices]),
        taille = as.numeric(inventaire$uncompressed_size[indices])))
      lignes_importees = lignes_importees + DBI::dbGetQuery(con,
        "SELECT count(*) AS n FROM am_lignes WHERE uid IS NOT NULL AND uid <> ''")$n[[1L]]
      fichiers_traites = max(indices)
      traitement = as.numeric(difftime(Sys.time(), t1, units = "secs"))
      ecoule = as.numeric(difftime(Sys.time(), debut, units = "secs"))
      debit = fichiers_traites / max(ecoule, 0.001)
      restant = (total - fichiers_traites) / debit
      journal("amendements", sprintf(
        "%d/%d (%.1f %%) | DuckDB %.1f s | %.1f fichiers/s | reste ~%.1f min",
        fichiers_traites, total, 100 * fichiers_traites / total,
        traitement, debit, restant / 60))
    }
  }, finally = unlink(dossier, recursive = TRUE))
  if (lignes_importees != total)
    stop("Nombre d'amendements importe different du nombre de fichiers JSON.")
  list(fichiers = fichiers_traites, lignes = lignes_importees)
}

#' Rechercher dans les amendements de la base locale
#' @param texte Expression recherchee dans le dispositif, l'expose ou le titre.
#' @param limite Nombre maximal de resultats.
#' @param cache Repertoire local de la base.
#' @return Tableau des amendements trouves.
#' @usage chercher_amendements(texte, limite = 100L,
#'   cache = tools::R_user_dir("assembleer", "cache"))
#' @export
chercher_amendements = function(texte, limite = 100L,
    cache = tools::R_user_dir("assembleer", "cache")) {
  stopifnot(is.character(texte), length(texte) == 1L, !is.na(texte), nzchar(texte),
            is.numeric(limite), length(limite) == 1L, is.finite(limite), limite >= 1)
  requete(paste0(
    "SELECT uid, numero, legislature, titre, sort, dossier_ref, texte_ref ",
    "FROM amendements WHERE contains(lower(coalesce(dispositif, '')), lower(?)) ",
    "OR contains(lower(coalesce(expose, '')), lower(?)) ",
    "OR contains(lower(coalesce(titre, '')), lower(?)) ",
    "ORDER BY uid LIMIT ", as.integer(limite)),
    params = list(texte, texte, texte), cache = cache)
}
