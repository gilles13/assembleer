# Import du dump PostgreSQL DOSLEG, sans serveur PostgreSQL.
.dosleg_url = "https://data.senat.fr/data/dosleg/dosleg.zip"

.dosleg_structure = function(con) {
  definitions = list()
  repeat {
    ligne = readLines(con, n = 1L, warn = FALSE)
    if (!length(ligne)) break
    if (!grepl("^CREATE TABLE (public\\.)?[A-Za-z_][A-Za-z_0-9]* \\($", ligne)) next
    nom = sub("^CREATE TABLE (public\\.)?([A-Za-z_][A-Za-z_0-9]*) \\($", "\\2", ligne)
    colonnes = character()
    repeat {
      ligne = readLines(con, n = 1L, warn = FALSE)
      if (!length(ligne)) stop("CREATE TABLE incomplet : ", nom)
      if (identical(ligne, ");")) break
      ligne = trimws(sub(",$", "", ligne))
      if (grepl("^(CONSTRAINT|PRIMARY|FOREIGN|UNIQUE|CHECK)\\b", ligne, ignore.case = TRUE)) next
      if (!grepl("^[A-Za-z_][A-Za-z_0-9]*[[:space:]]", ligne)) stop("Colonne inconnue : ", ligne)
      colonne = sub("^([A-Za-z_][A-Za-z_0-9]*)[[:space:]].*", "\\1", ligne)
      colonnes = c(colonnes, colonne)
    }
    if (!length(colonnes) || anyDuplicated(colonnes)) stop("Colonnes invalides : ", nom)
    definitions[[nom]] = colonnes
  }
  definitions
}

# Decode le format texte de COPY PostgreSQL : NULL = \\N, champs separes par TAB.
.dosleg_decoder = function(x) {
  if (identical(x, "\\N")) return(NA_character_)
  if (!grepl("\\", x, fixed = TRUE)) return(x)
  # Les sequences COPY sont converties avant insertion ; \\N n'est NULL
  # que lorsqu'il constitue le champ brut entier.
  morceaux = strsplit(x, "", fixed = TRUE)[[1L]]
  resultat = character(length(morceaux))
  j = 0L
  i = 1L
  while (i <= length(morceaux)) {
    c = morceaux[[i]]
    if (c == "\\" && i < length(morceaux)) {
      i = i + 1L
      c = morceaux[[i]]
      c = switch(c, "n" = "\n", "r" = "\r", "t" = "\t", "b" = "\b",
                 "f" = "\f", "v" = "\v", c)
    }
    j = j + 1L
    resultat[[j]] = c
    i = i + 1L
  }
  paste0(resultat[seq_len(j)], collapse = "")
}

.dosleg_ajouter = function(con, table, colonnes, lignes) {
  if (!length(lignes)) return(invisible(NULL))
  champs = strsplit(lignes, "\t", fixed = TRUE)
  # strsplit supprime parfois le dernier champ vide : le conserver.
  champs = lapply(seq_along(champs), function(i) {
    x = champs[[i]]
    if (endsWith(lignes[[i]], "\t")) x = c(x, "")
    x
  })
  if (any(lengths(champs) != length(colonnes)))
    stop("Nombre de champs COPY incorrect dans ", table)
  valeurs = lapply(seq_along(colonnes), function(j)
    vapply(champs, function(x) .dosleg_decoder(x[[j]]), character(1)))
  names(valeurs) = colonnes
  DBI::dbAppendTable(con, DBI::Id(schema = "senat", table = table),
                     as.data.frame(valeurs, optional = TRUE, stringsAsFactors = FALSE))
  invisible(NULL)
}

#' Importer la base DOSLEG du Senat dans DuckDB
#'
#' Charge integralement les 53 tables du dump PostgreSQL officiel dans le
#' schema `senat`. Toutes les colonnes sont conservees en VARCHAR afin de
#' preserver sans perte les codes, dates et valeurs du dump d'origine.
#' L'archive reste dans le cache. Le schema est remplace atomiquement.
#' @param cache Repertoire de stockage d'assembleer.
#' @param archive Archive ZIP locale ; telechargee si absente.
#' @param reimporter Forcer le rechargement d'une archive deja importee.
#' @param taille_lot Nombre de lignes par lot.
#' @return Tableau des effectifs par table, invisiblement.
#' @export
importer_dosleg = function(cache = tools::R_user_dir("assembleer", "cache"),
                           archive = file.path(cache, "dosleg.zip"),
                           reimporter = FALSE, taille_lot = 2000L) {
  stopifnot(length(taille_lot) == 1L, is.finite(taille_lot), taille_lot >= 1)
  taille_lot = as.integer(taille_lot)
  dir.create(dirname(archive), recursive = TRUE, showWarnings = FALSE)
  if (!file.exists(archive)) {
    tmp = paste0(archive, ".part")
    on.exit(unlink(tmp), add = TRUE)
    statut = system2("curl", c("-fLsS", "--retry", "3", "--connect-timeout", "30",
                               "-o", shQuote(tmp), shQuote(.dosleg_url)))
    if (!identical(as.integer(statut), 0L) || !file.rename(tmp, archive))
      stop("Telechargement DOSLEG impossible")
  }
  contenu = utils::unzip(archive, list = TRUE)
  if (!"dosleg.sql" %in% contenu$Name) stop("dosleg.sql absent de l'archive")
  empreinte = unname(tools::md5sum(archive))
  con = .base_an(cache)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  DBI::dbExecute(con, paste(
    "CREATE TABLE IF NOT EXISTS importations_officielles",
    "(source VARCHAR PRIMARY KEY, md5 VARCHAR, date_import TIMESTAMP, tables INTEGER, lignes BIGINT)"))
  precedent = DBI::dbGetQuery(con, "SELECT md5 FROM importations_officielles WHERE source = 'dosleg'")
  if (!reimporter && nrow(precedent) && identical(precedent$md5[[1L]], empreinte)) {
    message("DOSLEG deja importe (archive inchangee).")
    return(invisible(DBI::dbGetQuery(con, paste(
      "SELECT table_name AS table FROM information_schema.tables",
      "WHERE table_schema = 'senat' ORDER BY table_name"))))
  }
  lecteur = unz(archive, "dosleg.sql", open = "r")
  definitions = .dosleg_structure(lecteur)
  close(lecteur)
  if (length(definitions) != 53L) stop("Nombre inattendu de tables : ", length(definitions))

  lecteur = unz(archive, "dosleg.sql", open = "r")
  on.exit(try(close(lecteur), silent = TRUE), add = TRUE)
  DBI::dbBegin(con)
  valide = FALSE
  on.exit(if (!valide) DBI::dbRollback(con), add = TRUE)
  DBI::dbExecute(con, "DROP SCHEMA IF EXISTS senat CASCADE")
  DBI::dbExecute(con, "CREATE SCHEMA senat")
  for (nom in names(definitions)) {
    colonnes = definitions[[nom]]
    declaration = paste(sprintf('"%s" VARCHAR', colonnes), collapse = ", ")
    DBI::dbExecute(con, sprintf('CREATE TABLE senat."%s" (%s)', nom, declaration))
  }
  effectifs = integer()
  repeat {
    ligne = readLines(lecteur, n = 1L, warn = FALSE)
    if (!length(ligne)) break
    if (!grepl("^COPY (public\\.)?[A-Za-z_][A-Za-z_0-9]* \\(", ligne)) next
    nom = sub("^COPY (public\\.)?([A-Za-z_][A-Za-z_0-9]*) \\(.*", "\\2", ligne)
    if (!nom %in% names(definitions) || nom %in% names(effectifs))
      stop("COPY inconnu ou duplique : ", nom)
    texte = sub("^COPY [^(]+\\(([^)]+)\\) FROM stdin;$", "\\1", ligne)
    colonnes = trimws(strsplit(texte, ",", fixed = TRUE)[[1L]])
    if (!identical(colonnes, definitions[[nom]])) stop("Colonnes COPY non conformes : ", nom)
    lot = character()
    nombre = 0L
    repeat {
      ligne = readLines(lecteur, n = 1L, warn = FALSE)
      if (!length(ligne)) stop("Fin de COPY manquante : ", nom)
      if (identical(ligne, "\\.")) break
      lot = c(lot, ligne)
      if (length(lot) >= taille_lot) {
        .dosleg_ajouter(con, nom, colonnes, lot)
        nombre = nombre + length(lot)
        lot = character()
      }
    }
    .dosleg_ajouter(con, nom, colonnes, lot)
    nombre = nombre + length(lot)
    effectifs[nom] = nombre
    message("DOSLEG : ", nom, " (", nombre, " lignes)")
  }
  close(lecteur)
  if (length(effectifs) != 53L) stop("COPY manquants : ", 53L - length(effectifs))
  DBI::dbExecute(con, "DELETE FROM importations_officielles WHERE source = 'dosleg'")
  DBI::dbExecute(con, sprintf(
    "INSERT INTO importations_officielles VALUES ('dosleg', '%s', CURRENT_TIMESTAMP, %d, %d)",
    empreinte, length(effectifs), sum(as.double(effectifs))))
  DBI::dbCommit(con)
  valide = TRUE
  invisible(data.frame(table = names(effectifs), lignes = unname(effectifs), row.names = NULL))
}
