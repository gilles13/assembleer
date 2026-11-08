# Liens uniquement etablis par une cle officielle presente dans les tables.

#' Retrouver les liens parlementaires formels d'un objet
#'
#' Les rapprochements par titre, sujet ou similarite sont exclus.
#' Seules les correspondances exactes entre identifiants stockes sont rendues.
#' @param type Type de l'objet : dossier, amendement, texte ou scrutin.
#' @param uid Identifiant officiel de l'objet. Si NULL, utilise le premier identifiant local disponible.
#' @param cache Repertoire de la base locale DuckDB.
#' @return Un data.frame : source_type, source_uid, relation, cible_type,
#'   cible_uid, preuve_champ, preuve_valeur.
#' @export
liens_parlementaires = function(type = c("dossier", "amendement", "texte", "scrutin"), uid = NULL,
                                cache = tools::R_user_dir("assembleer", "cache")) {
  type = match.arg(type)
  if (is.null(uid)) {
    table = switch(type, dossier = "dossiers_legislatifs", amendement = "amendements",
                   texte = "dossiers_legislatifs", scrutin = "scrutins")
    colonne = if (type == "texte") "texte_ref" else "uid"
    candidats = requete(paste0("SELECT ", colonne, " AS uid FROM ", table,
      " WHERE ", colonne, " IS NOT NULL AND ", colonne,
      " <> '' ",
      if (type == "texte") "AND regexp_matches(texte_ref, '^[A-Z][A-Z0-9]{9,}$') " else "",
      "ORDER BY ", colonne, " LIMIT 1"), cache = cache)
    if (!nrow(candidats)) {
      message("Aucun identifiant disponible dans la base locale pour : ", type,
              ". Aucun telechargement lance.")
      return(data.frame(source_type = character(), source_uid = character(),
        relation = character(), cible_type = character(), cible_uid = character(),
        preuve_champ = character(), preuve_valeur = character()))
    }
    uid = candidats$uid[[1L]]
  }
  # Une reference courte telle que "BTA" n'identifie aucun texte.
  if (type == "texte" && !is.null(uid) && is.character(uid) &&
      length(uid) == 1L && !is.na(uid) &&
      !grepl("^[A-Z][A-Z0-9]{9,}$", uid)) {
    message("Reference de texte incomplete : ", uid)
    return(data.frame(source_type = character(), source_uid = character(),
      relation = character(), cible_type = character(), cible_uid = character(),
      preuve_champ = character(), preuve_valeur = character()))
  }
  if (!is.character(uid) || length(uid) != 1L || is.na(uid) || !nzchar(uid))
    stop("uid doit etre un identifiant non vide.", call. = FALSE)

  if (type == "dossier") {
    sql = "SELECT 'dossier' AS source_type, d.uid AS source_uid,
             'contient_amendement' AS relation, 'amendement' AS cible_type,
             a.uid AS cible_uid, 'amendements.dossier_ref = dossiers_legislatifs.uid' AS preuve_champ,
             a.dossier_ref AS preuve_valeur
           FROM dossiers_legislatifs d
           JOIN amendements a ON a.dossier_ref = d.uid
           WHERE d.uid = ?
           UNION ALL
           SELECT 'dossier', d.uid, 'reference_texte', 'texte', d.texte_ref,
             'dossiers_legislatifs.texte_ref', d.texte_ref
           FROM dossiers_legislatifs d
           WHERE d.uid = ? AND d.texte_ref IS NOT NULL AND regexp_matches(d.texte_ref, '^[A-Z][A-Z0-9]{9,}$')
           ORDER BY cible_type, cible_uid"
  } else if (type == "amendement") {
    sql = "SELECT 'amendement' AS source_type, a.uid AS source_uid,
             'concerne_dossier' AS relation, 'dossier' AS cible_type,
             d.uid AS cible_uid, 'amendements.dossier_ref = dossiers_legislatifs.uid' AS preuve_champ,
             a.dossier_ref AS preuve_valeur
           FROM amendements a
           JOIN dossiers_legislatifs d ON d.uid = a.dossier_ref
           WHERE a.uid = ?
           UNION ALL
           SELECT 'amendement', a.uid, 'reference_texte', 'texte', a.texte_ref,
             'amendements.texte_ref', a.texte_ref
           FROM amendements a
           WHERE a.uid = ? AND a.texte_ref IS NOT NULL AND regexp_matches(a.texte_ref, '^[A-Z][A-Z0-9]{9,}$')
           ORDER BY cible_type, cible_uid"
  } else if (type == "texte") {
    sql = "SELECT 'texte' AS source_type, a.texte_ref AS source_uid,
             'amendement_sur_texte' AS relation, 'amendement' AS cible_type,
             a.uid AS cible_uid, 'amendements.texte_ref' AS preuve_champ,
             a.texte_ref AS preuve_valeur
           FROM amendements a
           WHERE a.texte_ref = ? AND regexp_matches(a.texte_ref, '^[A-Z][A-Z0-9]{9,}$')
           UNION ALL
           SELECT 'texte', d.texte_ref, 'reference_dossier', 'dossier',
             d.uid, 'dossiers_legislatifs.texte_ref', d.texte_ref
           FROM dossiers_legislatifs d
           WHERE d.texte_ref = ? AND regexp_matches(d.texte_ref, '^[A-Z][A-Z0-9]{9,}$')
           ORDER BY cible_type, cible_uid"
  } else {
    sql = "SELECT 'scrutin' AS source_type, s.uid AS source_uid,
             'vote_de' AS relation, 'acteur' AS cible_type,
             v.acteur_ref AS cible_uid, 'votes.scrutin_uid = scrutins.uid' AS preuve_champ,
             v.scrutin_uid AS preuve_valeur
           FROM scrutins s
           JOIN votes v ON v.scrutin_uid = s.uid
           WHERE s.uid = ? ORDER BY v.acteur_ref"
  }
  requete(sql, params = if (type == "scrutin") list(uid) else list(uid, uid), cache = cache)
}
