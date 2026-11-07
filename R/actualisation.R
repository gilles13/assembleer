# URL officielles, conservees dans le package.
.sources_an = function() c(deputes = .url_deputes, amo40 = .archives[["amo40"]], amendements = .archives[["amendements"]], scrutins = .archives[["scrutins"]], dossiers = .archives[["dossiers"]])

# Pour les archives volumineuses, conserver les octets deja recus et afficher
# la progression. curl -C - reprend au dernier octet si le serveur l'autorise.
.telecharger_amendements = function(url, dossier) {
  executable = Sys.which("curl")
  if (!nzchar(executable))
    stop("Le programme curl est necessaire au telechargement des amendements.", call. = FALSE)
  partiel = file.path(dossier, "Amendements.json.zip.part")
  archive = file.path(dossier, "Amendements.json.zip")
  if (file.exists(archive)) return(archive)
  message("Amendements : telechargement (progression curl, reprise si possible).")
  for (tentative in seq_len(3L)) {
    if (file.exists(partiel))
      message("Reprise depuis ", format(file.info(partiel)$size, big.mark = " "), " octets.")
    code = suppressWarnings(system2(executable,
      args = c("--fail", "--location", "--progress-bar", "--connect-timeout", "30",
               "--max-time", "7200", "--continue-at", "-", "--output",
               shQuote(partiel), shQuote(url)), stdout = "", stderr = ""))
    if (identical(as.integer(code), 0L)) {
      valide = tryCatch({
        fichiers = zip::zip_list(partiel)$filename
        length(fichiers) > 0L && any(grepl("\\.json$", fichiers, ignore.case = TRUE))
      }, error = function(e) FALSE)
      if (!valide) stop("Archive d'amendements invalide : ", partiel, call. = FALSE)
      if (!file.rename(partiel, archive))
        stop("Impossible de conserver l'archive : ", archive, call. = FALSE)
      return(archive)
    }
    message("Amendements : tentative ", tentative, "/3 interrompue (curl : ", code, ").")
    if (tentative < 3L) Sys.sleep(2^tentative)
  }
  stop("Telechargement interrompu. Fichier partiel conserve : ", partiel,
       ". Relancer actualiser(sources = 'amendements') pour reprendre.", call. = FALSE)
}

# La comparaison HTTP est une optimisation : en l'absence de validateurs,
# on telecharge puis on compare MD5. Aucun changement ne declenche de reparse.
.verifier_source = function(source, ancien, dossier, reimporter = FALSE) {
  url = unname(.sources_an()[[source]])
  # Lors du premier import ou d'une reimportation, reutiliser le ZIP local.
  # L'archive validee est conservee meme si le parsing echoue ensuite.
  if (source == "amendements" && (!nrow(ancien) || reimporter)) {
    chemin = .telecharger_amendements(url, dossier)
    return(list(change = TRUE, etag = "", modified = "",
                md5 = unname(tools::md5sum(chemin)), chemin = chemin,
                verification = "archive locale", telecharge = FALSE,
                octets = 0))
  }
  requete = httr2::request(url) |> httr2::req_user_agent("assembleer/0.2") |>
    httr2::req_timeout(1800) |> httr2::req_retry(max_tries = 3)
  # HEAD n'est pas systematiquement supporte. On essaie, sans en dependre.
  entete = tryCatch(httr2::req_perform(httr2::req_method(requete, "HEAD")), error = function(e) NULL)
  if (!reimporter && !is.null(entete)) {
    code = httr2::resp_status(entete)
    etag = httr2::resp_header(entete, "etag")
    modifie = httr2::resp_header(entete, "last-modified")
    # L'ETag prime : une date identique ne doit pas masquer un ETag different.
    etag_connu = nrow(ancien) && !is.null(etag) && !is.na(ancien$etag[[1L]]) && nzchar(ancien$etag[[1L]])
    date_connue = nrow(ancien) && !is.null(modifie) && !is.na(ancien$modified[[1L]]) && nzchar(ancien$modified[[1L]])
    identique = if (etag_connu) identical(etag, ancien$etag[[1L]]) else
      if (date_connue && (is.null(etag) || !nzchar(etag)))
        identical(modifie, ancien$modified[[1L]]) else FALSE
    if (code == 304L || (code == 200L && identique)) {
      return(list(change = FALSE, etag = if (is.null(etag)) ancien$etag[[1L]] else etag,
                  modified = if (is.null(modifie)) ancien$modified[[1L]] else modifie,
                  md5 = ancien$md5[[1L]], chemin = NULL, verification = "HEAD", telecharge = FALSE, octets = 0))
    }
  }
  # Le HEAD reste non conditionnel pour comparer les validateurs distants.
  # Seul le GET de secours est conditionnel, pour autoriser un HTTP 304.
  if (!reimporter && nrow(ancien) && !is.na(ancien$etag[[1L]]) && nzchar(ancien$etag[[1L]])) {
    requete = httr2::req_headers(requete, `If-None-Match` = ancien$etag[[1L]])
  } else if (!reimporter && nrow(ancien) && !is.na(ancien$modified[[1L]]) && nzchar(ancien$modified[[1L]])) {
    requete = httr2::req_headers(requete, `If-Modified-Since` = ancien$modified[[1L]])
  }
  temporaire = tempfile(tmpdir = dossier, fileext = if (source == "deputes") ".csv" else ".zip")
  # req_retry traite les reponses HTTP transitoires, mais pas toujours les
  # interruptions du transfert curl. Retenter le GET complet dans ce cas.
  reponse = NULL
  erreur = NULL
  for (tentative in seq_len(3L)) {
    unlink(temporaire)
    essai = tryCatch(httr2::req_perform(requete, path = temporaire),
                     error = function(e) e)
    if (!inherits(essai, "error")) {
      reponse = essai
      break
    }
    erreur = conditionMessage(essai)
    if (tentative < 3L) Sys.sleep(2^(tentative - 1L))
  }
  if (is.null(reponse)) {
    unlink(temporaire)
    stop("Source ", source, " : echec du telechargement apres 3 tentatives : ",
         erreur, call. = FALSE)
  }
  # Ne jamais enregistrer ni importer une archive partielle/corrompue.
  if (httr2::resp_status(reponse) != 304L && source != "deputes") {
    valide = tryCatch({
      contenu = utils::unzip(temporaire, list = TRUE)
      nrow(contenu) > 0L && any(grepl("\\.json$", contenu$Name, ignore.case = TRUE))
    }, error = function(e) FALSE)
    if (!isTRUE(valide)) {
      unlink(temporaire)
      stop("Source ", source, " : archive ZIP invalide ou incomplete.", call. = FALSE)
    }
  }
  code = httr2::resp_status(reponse)
  if (code == 304L) {
    unlink(temporaire)
    return(list(change = FALSE, etag = ancien$etag[[1L]], modified = ancien$modified[[1L]],
                md5 = ancien$md5[[1L]], chemin = NULL, verification = "GET 304", telecharge = FALSE, octets = 0))
  }
  etag = httr2::resp_header(reponse, "etag")
  modifie = httr2::resp_header(reponse, "last-modified")
  octets = unname(file.info(temporaire)$size)
  md5 = unname(tools::md5sum(temporaire))
  if (!reimporter && nrow(ancien) && identical(md5, ancien$md5[[1L]])) {
    unlink(temporaire)
    return(list(change = FALSE, etag = if (is.null(etag)) "" else etag,
                modified = if (is.null(modifie)) "" else modifie, md5 = md5, chemin = NULL,
                verification = "GET MD5", telecharge = TRUE, octets = octets))
  }
  list(change = TRUE, etag = if (is.null(etag)) "" else etag,
       modified = if (is.null(modifie)) "" else modifie, md5 = md5, chemin = temporaire,
       verification = "GET MD5", telecharge = TRUE, octets = octets)
}

.extraire_an = function(x, type) {
  if (type == "amo40") {
    a = if (!is.null(x$acteur)) x$acteur else NULL
    if (!is.null(a)) return(list(table = "acteurs", ligne = data.frame(
      uid = .valeur(a$uid), nom = .valeur(a$etatCivil$ident$nom),
      prenom = .valeur(a$etatCivil$ident$prenom))))
    o = if (!is.null(x$organe)) x$organe else NULL
    if (!is.null(o)) return(list(table = "organes", ligne = data.frame(
      uid = .valeur(o$uid), code_type = .valeur(o$codeType),
      libelle = .valeur(o$libelle), libelle_abrege = .valeur(o$libelleAbrege),
      couleur = .valeur(o$couleurAssociee))))
    return(NULL)
  }
  s = .scrutin(x)
  d = s$syntheseVote$decompte
  res = data.frame(uid = .valeur(s$uid), numero = suppressWarnings(as.integer(.valeur(s$numero))),
                   date = as.Date(.valeur(s$dateScrutin)), titre = .valeur(s$titre),
                   type_vote = .valeur(s$typeVote$libelleTypeVote), sort = .valeur(s$sort$code),
                   votants = suppressWarnings(as.integer(.valeur(s$syntheseVote$nombreVotants))),
                   pour = suppressWarnings(as.integer(.valeur(d$pour))),
                   contre = suppressWarnings(as.integer(.valeur(d$contre))),
                   abstentions = suppressWarnings(as.integer(.valeur(d$abstentions))))
  groupes = .objets(s$ventilationVotes$organe$groupes$groupe)
  positions = c(pour = "pours", contre = "contres", abstention = "abstentions", non_votant = "nonVotants")
  effectifs = lapply(groupes, function(g) {
    n = suppressWarnings(as.integer(.valeur(g$nombreMembresGroupe)))
    if (is.na(n) || n < 0L)
      stop("Effectif de groupe absent ou invalide pour le scrutin ", .valeur(s$uid))
    data.frame(scrutin_uid = .valeur(s$uid), groupe_ref = .valeur(g$organeRef),
               total_groupe = n)
  })
  v = lapply(groupes, function(g) {
    nominatifs = g$vote$decompteNominatif
    do.call(rbind, lapply(names(positions), function(p) {
      personnes = .objets(nominatifs[[positions[[p]]]]$votant)
      if (!length(personnes)) return(NULL)
      data.frame(scrutin_uid = .valeur(s$uid),
                 acteur_ref = vapply(personnes, function(z) .valeur(z$acteurRef), character(1)),
                 groupe_ref = .valeur(g$organeRef), position = p,
                 par_delegation = vapply(personnes, function(z) identical(tolower(.valeur(z$parDelegation)), "true"), logical(1)))
    }))
  })
  list(table = "scrutins", ligne = res, votes = do.call(rbind, v),
       effectifs = do.call(rbind, effectifs))
}

#' Actualiser explicitement la base locale
#' @param sources Sources a verifier.
#' @param jours Delai minimal entre deux verifications, en jours.
#' @param forcer Ignorer le delai de verification.
#' @param reimporter Reimporter les archives, meme inchangees (migration des effectifs).
#' @param cache Repertoire local.
#' @param verbose Afficher les etapes de verification et d'importation.
#' @return Tableau de suivi : verification, telechargement, changement, fichiers
#'   traites, lignes importees et volume telecharge (octets).
#' @export
actualiser = function(sources = c("deputes", "amo40", "scrutins", "dossiers", "amendements"), jours = 1,
                       forcer = FALSE, reimporter = FALSE, cache = tools::R_user_dir("assembleer", "cache"),
                       verbose = TRUE) {
  sources = match.arg(sources, names(.sources_an()), several.ok = TRUE)
  stopifnot(length(jours) == 1L, is.numeric(jours), is.finite(jours), jours >= 0,
            is.logical(forcer), length(forcer) == 1L, !is.na(forcer))
  stopifnot(is.logical(verbose), length(verbose) == 1L, !is.na(verbose))
  journal = function(source, ...) {
    if (verbose) message(sprintf("[%s] [%s] %s",
      format(Sys.time(), "%H:%M:%S"), source, paste0(..., collapse = "")))
  }
  con = .base_an(cache)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  bilan = vector("list", length(sources))
  resultat = function(source, statut, verification, telecharge, modifie,
                      fichiers_traites = 0L, lignes_importees = 0L, octets = 0) {
    data.frame(source = source, statut = statut, verification = verification,
               telecharge = telecharge, modifie = modifie,
               donnees_modifiees = as.integer(fichiers_traites) > 0L,
               fichiers_traites = as.integer(fichiers_traites),
               lignes_importees = as.integer(lignes_importees), octets = as.numeric(octets))
  }
  for (i in seq_along(sources)) {
    source = sources[[i]]
    journal(source, "Debut de la verification")
    ancien = DBI::dbGetQuery(con, "SELECT * FROM sources WHERE source = ?", params = list(source))
    if (!forcer && !reimporter && nrow(ancien) && as.numeric(difftime(Sys.time(), ancien$controle[[1L]], units = "days")) < jours) {
      journal(source, "Verification ignoree (delai non ecoule)")
      bilan[[i]] = resultat(source, "non_verifie (delai)", "aucune", FALSE, FALSE)
      next
    }
    journal(source, "Controle HTTP / telechargement si necessaire (attente possible)")
    controle = .verifier_source(source, ancien, cache, reimporter = reimporter)
    journal(source, "Controle termine : ", controle$verification,
            "; telecharge = ", controle$telecharge, "; modifie = ", controle$change)
    fichiers_traites = 0L
    lignes_importees = 0L
    if (source == "dossiers" && controle$change && !reimporter) {
      journal(source, "Comparaison du contenu de l'archive avec le cache")
      inventaire = zip::zip_list(controle$chemin)
      noms = unique(inventaire$filename[grepl("^json/dossierParlementaire/[^/]+\\.json$", inventaire$filename)])
      archive_locale = file.path(cache, "Dossiers_Legislatifs.json.zip")
      if (file.exists(archive_locale)) {
        precedent = zip::zip_list(archive_locale)
        anciens = precedent$filename[grepl("^json/dossierParlementaire/[^/]+\\.json$", precedent$filename)]
        pos = match(noms, inventaire$filename)
        idx = match(noms, precedent$filename)
        if (length(noms) && length(noms) == length(anciens) && !anyNA(idx) &&
            identical(as.character(inventaire$crc32[pos]), as.character(precedent$crc32[idx])) &&
            identical(as.numeric(inventaire$uncompressed_size[pos]), as.numeric(precedent$uncompressed_size[idx])))
          controle$change = FALSE
      }
    }
    if (controle$change) {
      journal(source, "Debut de l'importation dans DuckDB")
      DBI::dbBegin(con)
      ok = FALSE
      tryCatch({
        if (source == "amendements") {
          # Import en lots : aucune requete SQL avec 144 000 parametres,
          # aucun split() geant et aucune copie des JSON dans une liste R.
          inventaire = zip::zip_list(controle$chemin)
          noms = inventaire$filename[grepl("\\.json$", inventaire$filename, ignore.case = TRUE)]
          if (!length(noms) || anyDuplicated(noms) ||
              any(grepl("(^/|(^|/)\\.\\.(/|$))", noms)))
            stop("Archive d'amendements inattendue.")
          total = length(noms)
          taille_lot = 500L
          nombre_lots = as.integer(ceiling(total / taille_lot))
          message("Amendements : ", format(total, big.mark = " "),
                  " JSON ; traitement par ", nombre_lots,
                  " lots de ", taille_lot, " maximum.")
          dossier = tempfile("assembleer-amendements-")
          dir.create(dossier)
          # Lecture vectorisee par DuckDB : pas de parsing JSON dans R.
          debut = Sys.time()
          tryCatch({
            DBI::dbExecute(con, "CREATE TABLE IF NOT EXISTS fichiers_uid (source VARCHAR, chemin VARCHAR, uid VARCHAR, table_cible VARCHAR, PRIMARY KEY(source, chemin))")
            DBI::dbExecute(con, "DELETE FROM amendements")
            DBI::dbExecute(con, "DELETE FROM fichiers_uid WHERE source = 'amendements'")
            DBI::dbExecute(con, "DELETE FROM fichiers WHERE source = 'amendements'")
            for (j in seq_len(nombre_lots)) {
              indices = seq.int((j - 1L) * taille_lot + 1L, min(j * taille_lot, total))
              lot = noms[indices]
              message(sprintf("Amendements : lot %d/%d, extraction de %d JSON...", j, nombre_lots, length(lot)))
              t0 = Sys.time()
              utils::unzip(controle$chemin, files = lot, exdir = dossier)
              extraction = as.numeric(difftime(Sys.time(), t0, units = "secs"))
              chemins = file.path(dossier, lot)
              if (any(!file.exists(chemins))) stop("JSON absent apres extraction.")
              message(sprintf("Amendements : lot %d/%d extrait en %.1f s ; lecture DuckDB...", j, nombre_lots, extraction))
              t1 = Sys.time()
              motif = DBI::dbQuoteString(con, file.path(dossier, "**", "*.json"))
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
              unlink(chemins)
              traitement = as.numeric(difftime(Sys.time(), t1, units = "secs"))
              ecoule = as.numeric(difftime(Sys.time(), debut, units = "secs"))
              debit = fichiers_traites / max(ecoule, 0.001)
              restant = (total - fichiers_traites) / debit
              message(sprintf(paste0("Amendements : %d/%d (%.1f %%) | extraction %.1f s | ",
                                     "DuckDB %.1f s | %.1f fichiers/s | reste ~%.1f min"),
                              fichiers_traites, total, 100 * fichiers_traites / total,
                              extraction, traitement, debit, restant / 60))
            }
          }, finally = unlink(dossier, recursive = TRUE))
        } else if (source == "dossiers") {
          # Les actes sont parcourus sans telecharger les textes eux-memes.
          noms = zip::zip_list(controle$chemin)$filename
          noms = unique(noms[grepl("^json/dossierParlementaire/[^/]+\\.json$", noms)])
          if (!length(noms)) stop("Archive de dossiers inattendue.")
          journal(source, length(noms), " fichiers JSON a lire")
          dossier = tempfile("assembleer-dossiers-")
          dir.create(dossier)
          tryCatch({
            DBI::dbExecute(con, "DELETE FROM dossiers_legislatifs")
            for (lot in split(noms, ceiling(seq_along(noms) / 200L))) {
              journal(source, "Extraction, parsing JSON et insertion : ",
                      fichiers_traites, "/", length(noms), " fichiers traites")
              utils::unzip(controle$chemin, files = lot, exdir = dossier)
              lignes = lapply(lot, function(nom) {
                d = jsonlite::fromJSON(file.path(dossier, nom), simplifyVector = FALSE)$dossierParlementaire
                if (is.null(d)) return(NULL)
                textes = character()
                parcourir = function(x) {
                  if (!is.list(x)) return(invisible(NULL))
                  if (!is.null(x$texteAssocie))
                    textes <<- c(textes, as.character(x$texteAssocie))
                  for (element in x) parcourir(element)
                  invisible(NULL)
                }
                parcourir(d$actesLegislatifs)
                textes = unique(textes[!is.na(textes) & nzchar(textes)])
                if (!length(textes)) textes = NA_character_
                data.frame(uid = .valeur(d$uid), titre = .valeur(d$titreDossier$titre),
                           texte_ref = textes)
              })
              lignes = Filter(Negate(is.null), lignes)
              if (length(lignes)) {
                donnees = do.call(rbind, lignes)
                DBI::dbAppendTable(con, "dossiers_legislatifs", donnees)
                lignes_importees = lignes_importees + nrow(donnees)
              }
              fichiers_traites = fichiers_traites + length(lot)
              unlink(file.path(dossier, lot))
            }
          }, finally = unlink(dossier, recursive = TRUE))
        } else if (source == "deputes") {
          journal(source, "Lecture du CSV et importation dans DuckDB")
          x = utils::read.csv(controle$chemin, fileEncoding = "UTF-8-BOM", check.names = FALSE)
          if (!nrow(x) || !"identifiant" %in% names(x)) stop("CSV deputes inattendu")
          DBI::dbWriteTable(con, "deputes", .nettoyer_noms(x), overwrite = TRUE)
          fichiers_traites = 1L
          lignes_importees = nrow(x)
        } else {
          inventaire = zip::zip_list(controle$chemin)
          noms = inventaire$filename[grepl("\\.json$", inventaire$filename, ignore.case = TRUE)]
          if (source == "amo40") noms = noms[grepl("(^|/)(acteur|organe)/[^/]+\\.json$", noms, ignore.case = TRUE)]
          if (!length(noms) || any(grepl("(^/|(^|/)\\.\\.(/|$))", noms))) stop("Archive ZIP inattendue")
          if (anyDuplicated(noms)) stop("Noms dupliques dans l'archive")
          DBI::dbExecute(con, "CREATE TABLE IF NOT EXISTS fichiers_uid (source VARCHAR, chemin VARCHAR, uid VARCHAR, table_cible VARCHAR, PRIMARY KEY(source, chemin))")
          avant = DBI::dbGetQuery(con, "SELECT chemin, taille, crc FROM fichiers WHERE source = ?", params = list(source))
          tailles = as.numeric(inventaire$uncompressed_size[match(noms, inventaire$filename)])
          empreintes = as.character(inventaire$crc32[match(noms, inventaire$filename)])
          names(empreintes) = noms
          changements = noms[!noms %in% avant$chemin | empreintes[noms] != avant$crc[match(noms, avant$chemin)] |
                            tailles != avant$taille[match(noms, avant$chemin)]]
          if (reimporter) changements = noms
          fichiers_traites = length(changements)
          journal(source, length(noms), " fichiers JSON dans l'archive ; ",
                  fichiers_traites, " a traiter")
          dossier = tempfile("assembleer-json-")
          dir.create(dossier)
          tryCatch({
            if (length(changements)) {
              journal(source, "Extraction de ", length(changements), " fichiers JSON")
              utils::unzip(controle$chemin, files = changements, exdir = dossier)
            }
            supprimes = setdiff(avant$chemin, noms)
            a_supprimer = unique(c(changements, supprimes))
            if (length(a_supprimer)) {
              anciens_ids = character()
              if (source == "scrutins") {
                # Identifier les scrutins via leur chemin, independamment du format du nom.
                # Les UID des fichiers modifies sont extraits des JSON existants uniquement
                # si un ancien UID est associe au chemin dans la table de suivi.
                if (DBI::dbExistsTable(con, "fichiers_uid")) {
                  refs = DBI::dbGetQuery(con, "SELECT chemin, uid FROM fichiers_uid WHERE source = ?", params = list(source))
                  anciens_ids = refs$uid[refs$chemin %in% a_supprimer]
                }
                if (length(anciens_ids)) {
                  DBI::dbExecute(con, paste0("DELETE FROM votes WHERE scrutin_uid IN (", paste(rep("?", length(anciens_ids)), collapse = ","), ")"), params = as.list(anciens_ids))
                  DBI::dbExecute(con, paste0("DELETE FROM effectifs_groupes_scrutins WHERE scrutin_uid IN (", paste(rep("?", length(anciens_ids)), collapse = ","), ")"), params = as.list(anciens_ids))
                  DBI::dbExecute(con, paste0("DELETE FROM scrutins WHERE uid IN (", paste(rep("?", length(anciens_ids)), collapse = ","), ")"), params = as.list(anciens_ids))
                }
              }
              if (source == "amendements") {
                refs = DBI::dbGetQuery(con, "SELECT chemin, uid FROM fichiers_uid WHERE source = 'amendements'")
                ids = refs$uid[refs$chemin %in% a_supprimer]
                if (length(ids)) DBI::dbExecute(con, paste0("DELETE FROM amendements WHERE uid IN (", paste(rep("?", length(ids)), collapse = ","), ")"), params = as.list(ids))
              }
              if (source == "amo40") {
                # AMO contient un grand nombre de fiches : on conserve les UID
                # des fiches non modifiees et on supprime les UID disparus via suivi.
                if (DBI::dbExistsTable(con, "fichiers_uid")) {
                  refs = DBI::dbGetQuery(con, "SELECT chemin, uid, table_cible FROM fichiers_uid WHERE source = ?", params = list(source))
                  for (table in c("acteurs", "organes")) {
                    ids = refs$uid[refs$chemin %in% a_supprimer & refs$table_cible == table]
                    if (length(ids)) DBI::dbExecute(con, paste0("DELETE FROM ", table, " WHERE uid IN (", paste(rep("?", length(ids)), collapse = ","), ")"), params = as.list(ids))
                  }
                }
              }
              DBI::dbExecute(con, "CREATE TABLE IF NOT EXISTS fichiers_uid (source VARCHAR, chemin VARCHAR, uid VARCHAR, table_cible VARCHAR, PRIMARY KEY(source, chemin))")
              if (length(a_supprimer)) DBI::dbExecute(con, paste0("DELETE FROM fichiers_uid WHERE source = ? AND chemin IN (", paste(rep("?", length(a_supprimer)), collapse = ","), ")"), params = c(list(source), as.list(a_supprimer)))
              lots = split(changements, ceiling(seq_along(changements) / 200))
              for (j in seq_along(lots)) {
                lot = lots[[j]]
                if (source == "amendements")
                  message("Amendements : lot ", j, "/", length(lots),
                          " (", min(j * 200L, length(changements)), "/",
                          length(changements), " fichiers)")
                journal(source, "Parsing et importation du lot ", j, "/", length(lots),
                        " (", length(lot), " JSON)")
                pars = lapply(lot, function(nom) {
                  x = jsonlite::fromJSON(file.path(dossier, nom), simplifyVector = FALSE)
                  if (source == "amendements") .extraire_amendement(x) else .extraire_an(x, source)
                })
                if (all(vapply(pars, is.null, logical(1)))) stop("Aucun JSON reconnu dans le lot")
                for (table in c("acteurs", "organes", "scrutins", "votes", "effectifs_groupes_scrutins", "amendements")) {
                  elements = lapply(pars, function(z) if (is.null(z)) NULL else if (table == "votes" && z$table == "scrutins") z$votes else if (table == "effectifs_groupes_scrutins" && z$table == "scrutins") z$effectifs else if (z$table == table) z$ligne else NULL)
                  elements = Filter(function(z) !is.null(z) && nrow(z), elements)
                  if (length(elements)) {
                    donnees = do.call(rbind, elements)
                    DBI::dbAppendTable(con, table, donnees)
                    lignes_importees = lignes_importees + nrow(donnees)
                  }
                }
                suivi = lapply(seq_along(lot), function(k) {
                  z = pars[[k]]
                  if (is.null(z)) return(NULL)
                  data.frame(source = source, chemin = lot[[k]], uid = z$ligne$uid[[1L]], table_cible = z$table)
                })
                suivi = Filter(Negate(is.null), suivi)
                if (length(suivi)) DBI::dbAppendTable(con, "fichiers_uid", do.call(rbind, suivi))
              }
            }
            DBI::dbExecute(con, "DELETE FROM fichiers WHERE source = ?", params = list(source))
            DBI::dbAppendTable(con, "fichiers", data.frame(source = source, chemin = noms,
                          crc = unname(empreintes[noms]), taille = as.numeric(tailles)))
          }, finally = unlink(dossier, recursive = TRUE))
        }
        DBI::dbCommit(con)
        journal(source, "Importation terminee : ", fichiers_traites,
                " fichiers, ", lignes_importees, " lignes")
        ok = TRUE
      }, error = function(e) {
        if (!ok) DBI::dbRollback(con)
        stop(e)
      })
    }
    DBI::dbExecute(con, "DELETE FROM sources WHERE source = ?", params = list(source))
    DBI::dbAppendTable(con, "sources", data.frame(source = source, url = unname(.sources_an()[[source]]),
        etag = controle$etag, modified = controle$modified, controle = Sys.time(), md5 = controle$md5))
    if (!is.null(controle$chemin)) {
      if (source %in% c("dossiers", "amendements") && controle$change) {
        destination = file.path(cache, if (source == "dossiers") "Dossiers_Legislatifs.json.zip" else "Amendements.json.zip")
        if (!identical(normalizePath(controle$chemin), normalizePath(destination, mustWork = FALSE)) &&
            !file.copy(controle$chemin, destination, overwrite = TRUE))
          warning("Impossible de conserver l'archive dans le cache.")
      }
      if (!identical(normalizePath(controle$chemin),
                     normalizePath(file.path(cache, "Amendements.json.zip"), mustWork = FALSE)))
        unlink(controle$chemin)
    }
    statut = if (!controle$change) "inchange" else if (!fichiers_traites)
      "archive_modifiee_donnees_identiques" else "actualise"
    journal(source, "Termine : ", statut, "; ", fichiers_traites,
            " fichiers ; ", lignes_importees, " lignes")
    bilan[[i]] = resultat(source, statut,
                           controle$verification, controle$telecharge, controle$change,
                           fichiers_traites, lignes_importees, controle$octets)
  }
  do.call(rbind, bilan)
}


# Migration locale : remplir les effectifs sans reimporter scrutins et votes.
.importer_effectifs_groupes = function(
    cache = tools::R_user_dir("assembleer", "cache")) {
  archive = file.path(cache, "scrutins.json.zip")
  if (!file.exists(archive))
    stop("Archive locale absente : ", archive, call. = FALSE)
  noms = zip::zip_list(archive)$filename
  noms = noms[grepl("^json/VTANR[0-9]+L[0-9]+V[0-9]+\\.json$", noms)]
  if (!length(noms)) stop("Aucun scrutin reconnu dans l'archive.", call. = FALSE)

  con = .base_an(cache)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  existants = DBI::dbGetQuery(con,
    "SELECT DISTINCT scrutin_uid FROM effectifs_groupes_scrutins")$scrutin_uid
  ids = sub("\\.json$", "", basename(noms))
  noms = noms[!ids %in% existants]
  # Plusieurs entrees ZIP peuvent porter le meme nom : n'en lire qu'une.
  noms = unique(noms)
  if (!length(noms)) return(invisible(0L))

  dossier = tempfile("assembleer-effectifs-")
  dir.create(dossier)
  on.exit(unlink(dossier, recursive = TRUE), add = TRUE)
  total = 0L
  ignores = character()
  DBI::dbBegin(con)
  tryCatch({
    for (lot in split(noms, ceiling(seq_along(noms) / 200L))) {
      utils::unzip(archive, files = lot, exdir = dossier)
      donnees = lapply(lot, function(nom) {
        s = .scrutin(jsonlite::fromJSON(
          file.path(dossier, nom), simplifyVector = FALSE))
        groupes = .objets(s$ventilationVotes$organe$groupes$groupe)
        if (!length(groupes)) stop("Groupes absents : ", nom)
        res = lapply(groupes, function(g) {
          uid = .valeur(g$organeRef)
          n = suppressWarnings(as.integer(.valeur(g$nombreMembresGroupe)))
          if (!nzchar(uid) || is.na(n) || n < 0L)
            stop("Effectif invalide dans ", nom, " pour ", uid)
          data.frame(scrutin_uid = .valeur(s$uid),
                     groupe_ref = uid, total_groupe = n)
        })
        res = do.call(rbind, res)
        # PO0 ne permet pas d'identifier une formation politique.
        if (any(res$groupe_ref == "PO0")) {
          ignores <<- c(ignores, .valeur(s$uid))
          return(NULL)
        }
        cle = paste(res$scrutin_uid, res$groupe_ref, sep = "/")
        doublons = duplicated(cle) | duplicated(cle, fromLast = TRUE)
        if (any(doublons)) {
          conflits = split(res$total_groupe[doublons], cle[doublons])
          if (any(vapply(conflits, \(z) length(unique(z)) > 1L, logical(1)))) {
            ignores <<- c(ignores, .valeur(s$uid))
            return(NULL)
          }
          res = res[!duplicated(cle), , drop = FALSE]
        }
        res
      })
      donnees = Filter(Negate(is.null), donnees)
      if (length(donnees)) {
        donnees = do.call(rbind, donnees)
        DBI::dbAppendTable(con, "effectifs_groupes_scrutins", donnees)
        total = total + nrow(donnees)
      }
      unlink(file.path(dossier, lot))
    }
    DBI::dbCommit(con)
  }, error = function(e) {
    try(DBI::dbRollback(con), silent = TRUE)
    stop(e)
  })
  if (length(ignores))
    warning(length(ignores), " scrutins ignores (PO0 ou effectifs contradictoires). Exemples : ",
            paste(utils::head(unique(ignores), 5L), collapse = ", "), call. = FALSE)
  invisible(total)
}
