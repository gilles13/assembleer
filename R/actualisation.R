# URL officielles, conservees dans le package.
.sources_an = function() c(deputes = .url_deputes, amo20 = .archives[["amo20"]], amo40 = .archives[["amo40"]], amendements = .archives[["amendements"]], scrutins = .archives[["scrutins"]], dossiers = .archives[["dossiers"]], reunions = .archives[["reunions"]], senateur = "https://data.senat.fr/data/senateurs/export_sens.zip", questions_ecrites = .archives[["questions_ecrites"]], debats = "https://data.assemblee-nationale.fr/static/openData/repository/17/VP/syceronbrut/syseron.xml.zip")

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
  if (source == "debats") {
    archive = file.path(dossier, "syseron.xml.zip")
    if (file.exists(archive) && (reimporter || !nrow(ancien)))
      return(list(change = TRUE, etag = "", modified = "",
                  md5 = unname(tools::md5sum(archive)), chemin = archive,
                  verification = "archive locale", telecharge = FALSE, octets = 0))
  }
  if (source == "senateur") {
    archive = file.path(dossier, "export_sens.zip")
    if (file.exists(archive) && (reimporter || !nrow(ancien)))
      return(list(change = TRUE, etag = "", modified = "",
                  md5 = unname(tools::md5sum(archive)), chemin = archive,
                  verification = "archive locale", telecharge = FALSE, octets = 0))
  }
  if (source == "amo20") {
    archive = file.path(dossier, "assembleer-AMO20.zip")
    if (file.exists(archive) && (!nrow(ancien) || reimporter))
      return(list(change = TRUE, etag = "", modified = "",
                  md5 = unname(tools::md5sum(archive)), chemin = archive,
                  verification = "archive locale", telecharge = FALSE, octets = 0))
  }
  if (source == "questions_ecrites") {
    archive = file.path(dossier, "Questions_ecrites.json.zip")
    if (file.exists(archive) && (reimporter || !nrow(ancien)))
      return(list(change = TRUE, etag = "", modified = "",
                  md5 = unname(tools::md5sum(archive)), chemin = archive,
                  verification = "archive locale", telecharge = FALSE, octets = 0))
    temporaire = file.path(dossier, "Questions_ecrites.json.zip.part")
    code = system2("curl", c("--http1.1", "-fL", "--retry", "5",
                             "--retry-all-errors", "--retry-delay", "2",
                             "--continue-at", "-", "-o", shQuote(temporaire),
                             shQuote(url)))
    if (code != 0L)
      stop("Telechargement interrompu (curl : ", code,
           "). Fichier partiel conserve : ", temporaire)
    contenu = utils::unzip(temporaire, list = TRUE)$Name
    if (!any(grepl("^json/[^/]+\\.json$", contenu)))
      stop("Archive des questions ecrites invalide.")
    md5 = unname(tools::md5sum(temporaire))
    if (!reimporter && nrow(ancien) && identical(md5, ancien$md5[[1L]]))
      return(list(change = FALSE, etag = "", modified = "", md5 = md5,
                  chemin = NULL, verification = "GET MD5", telecharge = TRUE,
                  octets = file.info(temporaire)$size))
    destination = tempfile(tmpdir = dossier, fileext = ".zip")
    if (!file.rename(temporaire, destination)) stop("Impossible de conserver le ZIP temporaire.")
    return(list(change = TRUE, etag = "", modified = "", md5 = md5,
                chemin = destination, verification = "GET MD5", telecharge = TRUE,
                octets = file.info(destination)$size))
  }
  if (source == "reunions") {
    archive = file.path(dossier, "Agenda.json.zip")
    if (file.exists(archive) && (reimporter || !nrow(ancien))) {
      return(list(change = TRUE, etag = "", modified = "",
                  md5 = unname(tools::md5sum(archive)), chemin = archive,
                  verification = "archive locale", telecharge = FALSE, octets = 0))
    }
    temporaire = tempfile(tmpdir = dossier, fileext = ".zip")
    on.exit(if (file.exists(temporaire)) unlink(temporaire), add = TRUE)
    code = system2("curl", c("-fL", "--retry", "3", "-o", shQuote(temporaire), shQuote(url)))
    if (!identical(as.integer(code), 0L)) stop("Echec du telechargement de l'agenda (curl).")
    contenu = utils::unzip(temporaire, list = TRUE)$Name
    if (!any(grepl("^json/reunion/[^/]+\\.json$", contenu))) stop("Archive Agenda invalide.")
    md5 = unname(tools::md5sum(temporaire))
    if (!reimporter && nrow(ancien) && identical(md5, ancien$md5[[1L]]))
      return(list(change = FALSE, etag = "", modified = "", md5 = md5,
                  chemin = NULL, verification = "GET MD5", telecharge = TRUE,
                  octets = file.info(temporaire)$size))
    destination = tempfile(tmpdir = dossier, fileext = ".zip")
    if (!file.rename(temporaire, destination)) stop("Impossible de conserver le ZIP temporaire.")
    return(list(change = TRUE, etag = "", modified = "", md5 = md5,
                chemin = destination, verification = "GET MD5", telecharge = TRUE,
                octets = file.info(destination)$size))
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
      nrow(contenu) > 0L && any(grepl(if (source == "senateur") "(^|/)export_sens\\.sql$" else if (source == "debats") "\\.xml$" else "\\.json$", contenu$Name, ignore.case = TRUE))
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
                   abstentions = suppressWarnings(as.integer(.valeur(d$abstentions))),
                   dossier_uid = .valeur(s$objet$dossierLegislatif$dossierRef))
  groupes = .objets(s$ventilationVotes$organe$groupes$groupe)
  positions = c(pour = "pours", contre = "contres", abstention = "abstentions", non_votant = "nonVotants")
  effectifs = lapply(groupes, function(g) {
    n = suppressWarnings(as.integer(.valeur(g$nombreMembresGroupe)))
    if (is.na(n) || n < 0L)
      stop("Effectif de groupe absent ou invalide pour le scrutin ", .valeur(s$uid))
    data.frame(scrutin_uid = .valeur(s$uid), groupe_ref = .valeur(g$organeRef),
               total_groupe = n)
  })
  if (length(effectifs))
    effectifs = lapply(seq_along(effectifs), function(i) {
      cbind(effectifs[[i]], rang = as.integer(i))
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

# Importer les donnees d'une source dans la transaction ouverte par actualiser().
.importer_source = function(con, source, controle, cache, reimporter, verbose, journal) {
  fichiers_traites = 0L
  lignes_importees = 0L
        if (source == "debats") {
          compte = .importer_debats(con, controle$chemin, remplacer = TRUE)
          fichiers_traites = compte$fichiers
          lignes_importees = compte$lignes
        } else if (source == "senateur") {
          compte = .importer_senateur(con, controle$chemin, journal)
          fichiers_traites = compte$tables
          lignes_importees = compte$lignes
        } else if (source == "questions_ecrites") {
          inventaire = utils::unzip(controle$chemin, list = TRUE)$Name
          noms = inventaire[grepl("^json/[^/]+\\.json$", inventaire)]
          if (!length(noms) || anyDuplicated(noms))
            stop("Archive des questions ecrites inattendue.")
          journal(source, "Extraction de ", length(noms), " fichiers JSON")
          dossier = tempfile("assembleer-questions-")
          dir.create(dossier)
          tryCatch({
            statut = system2("unzip", c("-oq", shQuote(controle$chemin), "-d", shQuote(dossier)))
            if (!identical(as.integer(statut), 0L)) stop("Echec de l'extraction ZIP des questions.")
            extraits = list.files(file.path(dossier, "json"), pattern = "\\.json$")
            if (length(extraits) != length(noms)) stop("Extraction incomplete des questions ecrites.")
            journal(source, "Importation DuckDB en une requete")
            chemin = gsub("'", "''", file.path(dossier, "json", "*.json"), fixed = TRUE)
            DBI::dbExecute(con, "DELETE FROM questions_ecrites")
            DBI::dbExecute(con, paste0(
              "INSERT INTO questions_ecrites ",
              "SELECT question->>'uid', question ",
              "FROM read_json('", chemin, "', columns = {question: 'JSON'})"))
            lignes_importees = DBI::dbGetQuery(con,
              "SELECT COUNT(*) AS n FROM questions_ecrites")$n[[1L]]
            fichiers_traites = length(noms)
            if (lignes_importees != fichiers_traites)
              stop("Nombre de questions different du nombre de fichiers JSON.")
            journal(source, "Verification : ", lignes_importees, " questions importees")
          }, finally = unlink(dossier, recursive = TRUE))
        } else if (source == "amo20") {
          inventaire = utils::unzip(controle$chemin, list = TRUE)$Name
          noms = inventaire[grepl("^json/(acteur|organe)/[^/]+\\.json$", inventaire)]
          if (!length(noms) || anyDuplicated(noms)) stop("Archive AMO20 inattendue.")
          DBI::dbExecute(con, "DELETE FROM mandats_organes")
          DBI::dbExecute(con, "DELETE FROM mandats")
          # AMO20 contient aussi des acteurs historiques absents d'AMO40.
          # L'import conserve les identites et organes existants, puis les complete.
          valeur = function(x) {
            y = unlist(x, use.names = FALSE)
            if (!length(y)) NA_character_ else as.character(y[[1L]])
          }
          dossier = tempfile("assembleer-amo20-")
          dir.create(dossier)
          tryCatch({
            for (lot in split(noms, ceiling(seq_along(noms) / 200L))) {
              utils::unzip(controle$chemin, files = lot, exdir = dossier)
              for (nom in lot) {
                x = jsonlite::fromJSON(file.path(dossier, nom), simplifyVector = FALSE)
                if (!is.null(x$organe)) {
                  o = x$organe
                  DBI::dbExecute(con, "INSERT INTO organes VALUES (?, ?, ?, ?, ?) ON CONFLICT (uid) DO UPDATE SET code_type = excluded.code_type, libelle = excluded.libelle, libelle_abrege = excluded.libelle_abrege, couleur = excluded.couleur",
                    params = list(valeur(o$uid), valeur(o$codeType), valeur(o$libelle), valeur(o$libelleAbrege), valeur(o$couleurAssociee)))
                }
                if (!is.null(x$acteur)) {
                  a = x$acteur
                  DBI::dbExecute(con, "INSERT INTO acteurs VALUES (?, ?, ?) ON CONFLICT (uid) DO UPDATE SET nom = excluded.nom, prenom = excluded.prenom",
                    params = list(valeur(a$uid), valeur(a$etatCivil$ident$nom), valeur(a$etatCivil$ident$prenom)) )
                  mandats = a$mandats$mandat
                  if (!is.null(mandats$uid)) mandats = list(mandats)
                  for (m in mandats) {
                    if (is.null(m$uid)) next
                    DBI::dbExecute(con, "INSERT INTO mandats VALUES (?, ?, ?, ?, CAST(? AS DATE), CAST(? AS DATE))",
                      params = list(valeur(m$uid), valeur(m$acteurRef), valeur(m$typeOrgane),
                                    valeur(m$infosQualite$libQualite), valeur(m$dateDebut), valeur(m$dateFin)))
                    refs = unique(as.character(unlist(m$organes$organeRef, use.names = FALSE)))
                    for (ref in refs) if (!is.na(ref) && nzchar(ref))
                      DBI::dbExecute(con, "INSERT INTO mandats_organes VALUES (?, ?) ON CONFLICT DO NOTHING",
                        params = list(valeur(m$uid), ref))
                    lignes_importees = lignes_importees + 1L
                  }
                }
                fichiers_traites = fichiers_traites + 1L
              }
              unlink(file.path(dossier, lot))
              journal(source, "Importation : ", fichiers_traites, "/", length(noms), " JSON")
            }
          }, finally = unlink(dossier, recursive = TRUE))
        } else if (source == "reunions") {
          inventaire = utils::unzip(controle$chemin, list = TRUE)$Name
          noms = inventaire[grepl("^json/reunion/[^/]+\\.json$", inventaire)]
          if (!length(noms) || anyDuplicated(noms)) stop("Archive Agenda inattendue.")
          total = length(noms)
          debut_import = proc.time()[["elapsed"]]
          journal(source, total, " fichiers JSON a traiter ; lots de 200 maximum")
          DBI::dbExecute(con, "DELETE FROM reunions_points_odj")
          DBI::dbExecute(con, "DELETE FROM reunions")
          for (lot in split(noms, ceiling(seq_along(noms) / 200L))) {
            lignes = lapply(lot, function(nom) {
              r = jsonlite::fromJSON(unz(controle$chemin, nom), simplifyVector = FALSE)$reunion
              if (is.null(r) || is.null(r$uid)) stop("Reunion invalide : ", nom)
              uid = .valeur(r$uid)
              points = .objets(r$ODJ$pointsODJ$pointODJ)
              lignes_points = lapply(points, function(p) {
                refs = unlist(p$dossiersLegislatifsRefs$dossierRef, use.names = FALSE)
                if (!length(refs)) refs = NA_character_
                data.frame(uid = .valeur(p$uid), reunion_ref = uid,
                           dossier_ref = as.character(refs), objet = .valeur(p$objet),
                           type_point = .valeur(p$typePointODJ), etat = .valeur(p$cycleDeVie$etat),
                           procedure = .valeur(p$procedure), nature_travaux = .valeur(p$natureTravauxODJ))
              })
              list(reunion = data.frame(uid = uid, debut = .valeur(r$timeStampDebut),
                         fin = .valeur(r$timeStampFin), session_ref = .valeur(r$sessionRef),
                         organe_ref = .valeur(r$organeReuniRef),
                         compte_rendu_ref = .valeur(r$compteRenduRef)),
                   points = lignes_points)
            })
            DBI::dbAppendTable(con, "reunions", do.call(rbind, lapply(lignes, `[[`, "reunion")))
            points = unlist(lapply(lignes, `[[`, "points"), recursive = FALSE)
            if (length(points)) {
              points = do.call(rbind, points)
              # Un point peut referencer plusieurs dossiers : conserver une ligne par couple.
              DBI::dbAppendTable(con, "reunions_points_odj", points)
              lignes_importees = lignes_importees + nrow(points)
            }
            fichiers_traites = fichiers_traites + length(lot)
            if (verbose) {
              ecoule = proc.time()[["elapsed"]] - debut_import
              restant = if (fichiers_traites < total && ecoule > 0)
                ecoule * (total - fichiers_traites) / fichiers_traites else 0
              journal(source, sprintf(
                "Progression : %d/%d (%.1f %%) ; ecoule : %.0f s ; restant estime : %.0f s",
                fichiers_traites, total, 100 * fichiers_traites / total, ecoule, restant))
            }
          }
        } else if (source == "amendements") {
          compte = .importer_amendements(con, controle$chemin, journal)
          fichiers_traites = compte$fichiers
          lignes_importees = compte$lignes
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
              if (source == "scrutins") {
                statut = system2("unzip", c("-oq", shQuote(controle$chemin),
                                             "-d", shQuote(dossier)))
                if (statut != 0L) stop("Echec de l'extraction des scrutins")
              } else {
                utils::unzip(controle$chemin, files = changements, exdir = dossier)
              }
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
                journal(source, "Parsing et importation du lot ", j, "/", length(lots),
                        " (", length(lot), " JSON)")
                pars = lapply(lot, function(nom) {
                  x = jsonlite::fromJSON(file.path(dossier, nom), simplifyVector = FALSE)
                  .extraire_an(x, source)
                })
                if (all(vapply(pars, is.null, logical(1)))) stop("Aucun JSON reconnu dans le lot")
                for (table in c("acteurs", "organes", "scrutins", "votes", "effectifs_groupes_scrutins")) {
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
  list(fichiers = fichiers_traites, lignes = lignes_importees)
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
actualiser = function(sources = c("deputes", "amo40", "amo20", "scrutins", "dossiers", "amendements", "reunions", "debats"), jours = 1,
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
        compte = .importer_source(con, source, controle, cache, reimporter, verbose, journal)
        fichiers_traites = compte$fichiers
        lignes_importees = compte$lignes
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
      if (source %in% c("dossiers", "amendements", "reunions", "senateur", "questions_ecrites", "debats") && controle$change) {
        destination = file.path(cache, if (source == "debats") "syseron.xml.zip" else if (source == "dossiers") "Dossiers_Legislatifs.json.zip" else if (source == "reunions") "Agenda.json.zip" else if (source == "senateur") "export_sens.zip" else if (source == "questions_ecrites") "Questions_ecrites.json.zip" else "Amendements.json.zip")
        if (!identical(normalizePath(controle$chemin), normalizePath(destination, mustWork = FALSE)) &&
            !file.copy(controle$chemin, destination, overwrite = TRUE))
          warning("Impossible de conserver l'archive dans le cache.")
      }
      if (!identical(normalizePath(controle$chemin),
                     normalizePath(file.path(cache, "Amendements.json.zip"), mustWork = FALSE)) &&
          !identical(normalizePath(controle$chemin),
                     normalizePath(file.path(cache, "assembleer-AMO20.zip"), mustWork = FALSE)) &&
          !identical(normalizePath(controle$chemin),
                     normalizePath(file.path(cache, "export_sens.zip"), mustWork = FALSE)) &&
          !identical(normalizePath(controle$chemin),
                     normalizePath(file.path(cache, "Questions_ecrites.json.zip"), mustWork = FALSE)) &&
          !identical(normalizePath(controle$chemin),
                     normalizePath(file.path(cache, "syseron.xml.zip"), mustWork = FALSE)))
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
        res$rang = seq_len(nrow(res))
        if (!nrow(res)) {
          ignores <<- c(ignores, .valeur(s$uid))
          return(NULL)
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
    warning(length(ignores), " scrutins sans effectifs exploitables. Exemples : ",
            paste(utils::head(unique(ignores), 5L), collapse = ", "), call. = FALSE)
  invisible(total)
}
