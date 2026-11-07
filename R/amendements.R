# Extraction limitee aux champs utiles pour une recherche documentaire.
# Les chemins absents restent vides : aucun contenu n'est reconstruit.
.am_texte = function(x) {
  if (is.null(x)) return(NA_character_)
  if (is.list(x)) {
    if (!is.null(x$texte)) return(.am_texte(x$texte))
    if (!is.null(x$contenu)) return(.am_texte(x$contenu))
    if (!is.null(x$valeur)) return(.am_texte(x$valeur))
    return(NA_character_)
  }
  if (length(x) != 1L || is.na(x)) return(NA_character_)
  as.character(x)
}

# Un champ JSON peut etre absent, null ou une valeur atomique.
.am_champ = function(x, chemin) {
  for (nom in chemin) {
    if (!is.list(x) || is.null(names(x)) || !nom %in% names(x)) return(NULL)
    x = x[[nom]]
  }
  x
}

.extraire_amendement = function(x) {
  a = .am_champ(x, "amendement")
  if (is.null(a)) return(NULL)
  contenu = .am_champ(a, c("corps", "contenuAuteur"))
  dispositif = .am_texte(.am_champ(contenu, "dispositif"))
  expose = .am_texte(.am_champ(contenu, "exposeSommaire"))
  if (is.na(dispositif)) dispositif = .am_texte(.am_champ(a, c("corps", "dispositif")))
  if (is.na(expose)) expose = .am_texte(.am_champ(a, c("corps", "exposeSommaire")))
  uid = .valeur(.am_champ(a, "uid"))
  if (!nzchar(uid)) stop("Amendement sans UID")
  ligne = data.frame(
    uid = uid, numero = .valeur(.am_champ(a, c("identification", "numeroLong"))),
    legislature = suppressWarnings(as.integer(.valeur(.am_champ(a, "legislature")))),
    titre = .am_texte(.am_champ(a, c("corps", "cartouche", "designationArticle"))),
    dispositif = dispositif, expose = expose,
    sort = .valeur(.am_champ(a, c("cycleDeVie", "sort"))),
    dossier_ref = .valeur(.am_champ(a, "dossierLegislatifRef")),
    texte_ref = .valeur(.am_champ(a, "texteLegislatifRef")))
  list(table = "amendements", ligne = ligne)
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
