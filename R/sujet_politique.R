# Recherche transversale dans les quatre familles de documents parlementaires.

#' Rechercher les documents relatifs a un sujet politique
#'
#' Une correspondance textuelle n'est pas un lien parlementaire officiel.
#' Chaque resultat conserve son identifiant et sa source documentaire.
#' @param texte Expression recherchee dans les titres des documents.
#' @param limite Nombre maximal de resultats par categorie.
#' @param cache Repertoire de la base DuckDB.
#' @return Liste de quatre data.frames : debats, textes, amendements, votes.
#' @export
sujet_politique = function(texte, limite = 100L,
                           cache = tools::R_user_dir("assembleer", "cache")) {
  if (!is.character(texte) || length(texte) != 1L || is.na(texte) ||
      !nzchar(trimws(texte)))
    stop("texte doit etre une expression non vide.", call. = FALSE)
  if (!is.numeric(limite) || length(limite) != 1L || is.na(limite) ||
      !is.finite(limite) || limite < 1 || limite > .Machine$integer.max ||
      limite != as.integer(limite))
    stop("limite doit etre un entier positif.", call. = FALSE)
  limite = as.integer(limite)
  con = .connexion_lecture(cache)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  if (!DBI::dbExistsTable(con, "debats_points"))
    stop('Debats non importes : executer actualiser(sources = "debats").', call. = FALSE)
  chercher = function(sql) DBI::dbGetQuery(con, paste0(sql, " LIMIT ", limite),
                                          params = list(texte))
  list(
    debats = chercher("SELECT fichier, position, id_syceron, titre
      FROM debats_points
      WHERE titre IS NOT NULL AND contains(lower(titre), lower(?))
      ORDER BY fichier, position"),
    textes = chercher("SELECT uid, titre, texte_ref
      FROM dossiers_legislatifs
      WHERE titre IS NOT NULL AND contains(lower(titre), lower(?))
      ORDER BY titre, uid"),
    amendements = chercher("SELECT uid, numero, titre, sort, dossier_ref, texte_ref
      FROM amendements
      WHERE titre IS NOT NULL AND contains(lower(titre), lower(?))
      ORDER BY numero, uid"),
    votes = chercher("SELECT uid, numero, date, titre, sort, pour, contre, abstentions
      FROM scrutins
      WHERE titre IS NOT NULL AND contains(lower(titre), lower(?))
      ORDER BY date DESC, numero DESC")
  )
}
