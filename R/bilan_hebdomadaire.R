#' Bilan hebdomadaire des scrutins publics
#'
#' Regroupe les scrutins par dossier legislatif a partir des archives JSON
#' deja presentes dans le cache. Aucun acces reseau ni modification de la base.
#' Les adoptions/rejets comptent des scrutins, pas des textes de loi.
#' @param semaine Premier jour de la semaine (lundi).
#' @param cache Repertoire du cache assembleer.
#' @return Liste de deux data.frames : dossiers (synthese) et scrutins (detail).
#' @export
bilan_hebdomadaire = function(semaine, cache = tools::R_user_dir("assembleer", "cache")) {
  semaine = as.Date(semaine)
  if (length(semaine) != 1L || is.na(semaine))
    stop("semaine doit etre une date valide.", call. = FALSE)
  if (as.POSIXlt(semaine)$wday != 1L)
    stop("semaine doit etre un lundi.", call. = FALSE)
  archive = file.path(cache, "scrutins.json.zip")
  if (!file.exists(archive)) stop("Archive scrutins.json.zip absente du cache.", call. = FALSE)
  con = .connexion_lecture(cache)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  s = DBI::dbGetQuery(con, paste0(
    "SELECT uid, numero, date, titre, type_vote, sort, pour, contre, abstentions ",
    "FROM scrutins WHERE date >= ? AND date < ? ORDER BY date, numero"),
    params = list(as.character(semaine), as.character(semaine + 7L)))
  if (!nrow(s)) return(list(dossiers = data.frame(), scrutins = s))
  noms = utils::unzip(archive, list = TRUE)$Name
  fichiers = paste0("json/", s$uid, ".json")
  manquants = !fichiers %in% noms
  if (any(manquants)) warning(sum(manquants), " JSON de scrutins absents de l'archive.", call. = FALSE)
  refs = rep(NA_character_, nrow(s))
  for (i in which(!manquants)) {
    x = tryCatch(jsonlite::fromJSON(unz(archive, fichiers[i]), simplifyVector = FALSE),
                 error = function(e) NULL)
    if (is.null(x)) next
    scrutin = .scrutin(x)
    dossier = scrutin$objet$dossierLegislatif
    ref = if (is.list(dossier)) dossier$dossierRef else NULL
    if (is.character(ref) && length(ref) == 1L && !is.na(ref)) refs[i] = ref
  }
  s$dossier_uid = refs
  d = DBI::dbGetQuery(con, "SELECT uid, MAX(titre) AS titre_dossier FROM dossiers_legislatifs GROUP BY uid")
  s$titre_dossier = d$titre_dossier[match(s$dossier_uid, d$uid)]
  s$nature = ifelse(grepl("amendement", s$titre, ignore.case = TRUE), "amendement",
              ifelse(grepl("article", s$titre, ignore.case = TRUE), "article",
              ifelse(grepl("ensemble", s$titre, ignore.case = TRUE), "ensemble du texte", "autre")))
  cle = ifelse(is.na(s$dossier_uid), paste0("sans dossier : ", s$uid), s$dossier_uid)
  groupes = split(seq_len(nrow(s)), factor(cle, levels = unique(cle)))
  dossiers = do.call(rbind, lapply(groupes, function(ix) {
    z = s[ix, , drop = FALSE]
    data.frame(dossier_uid = z$dossier_uid[1L],
               titre = z$titre_dossier[1L],
               scrutins = nrow(z),
               adoptes = sum(z$sort == "adopte", na.rm = TRUE) + sum(z$sort == "adopt\u00e9", na.rm = TRUE),
               rejetes = sum(z$sort == "rejete", na.rm = TRUE) + sum(z$sort == "rejet\u00e9", na.rm = TRUE),
               amendements = sum(z$nature == "amendement"),
               articles = sum(z$nature == "article"),
               ensembles = sum(z$nature == "ensemble du texte"),
               autres = sum(z$nature == "autre"))
  }))
  dossiers = dossiers[order(-dossiers$scrutins), , drop = FALSE]
  rownames(dossiers) = NULL
  list(dossiers = dossiers, scrutins = s)
}
