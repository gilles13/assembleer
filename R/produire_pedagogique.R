#' Produire un dossier citoyen PDF a partir des donnees parlementaires locales
#'
#' Explique le parcours legislatif a partir des documents, reunions et
#' amendements effectivement rattaches au dossier dans la base AN.
#' Les donnees du Senat et DOLE ne sont pas encore importees : aucune
#' correspondance interchambres n'est deduite d'un titre.
#' @param uid Identifiant officiel du dossier AN (DLR...).
#' @param sortie Chemin du PDF, dans /tmp par defaut.
#' @param cache Repertoire de la base DuckDB.
#' @param ouvrir Ouvrir le PDF produit.
#' @param modele Modele R Markdown commun du package.
#' @return Chemin du PDF, invisiblement.
#' @export
produire_pedagogique = function(uid,
    sortie = file.path('/tmp', paste0('assembleer-citoyen-', uid, '.pdf')),
    cache = tools::R_user_dir('assembleer', 'cache'), ouvrir = TRUE,
    modele = system.file('modeles', 'template.Rmd', package = 'assembleer')) {
  if (length(uid) != 1L || is.na(uid) || !grepl('^DLR[A-Za-z0-9]+$', uid))
    stop('uid doit etre un identifiant de dossier AN (DLR...).', call. = FALSE)
  if (length(sortie) != 1L || is.na(sortie) ||
      tolower(tools::file_ext(sortie)) != 'pdf')
    stop('sortie doit designer un fichier PDF.', call. = FALSE)
  dossier = requete('SELECT DISTINCT uid, titre, texte_ref FROM dossiers_legislatifs WHERE uid = ?',
                    params = list(uid), cache = cache)
  if (!nrow(dossier)) stop('Dossier absent de la base locale : ', uid, call. = FALSE)
  titre = unique(dossier$titre[!is.na(dossier$titre) & nzchar(dossier$titre)])[1L]
  if (is.na(titre)) titre = uid
  refs = unique(dossier$texte_ref)
  refs = refs[!is.na(refs) & grepl('^[A-Z][A-Z0-9]{9,}$', refs)]
  an = refs[grepl('ANR', refs, fixed = TRUE)]
  senat = refs[grepl('SNR', refs, fixed = TRUE)]
  reunions = requete(
    'SELECT DISTINCT r.uid, r.debut, r.organe_ref, r.compte_rendu_ref, p.objet
     FROM reunions_points_odj p JOIN reunions r ON r.uid = p.reunion_ref
     WHERE p.dossier_ref = ? ORDER BY r.debut, r.uid',
    params = list(uid), cache = cache)
  amendements = requete(
    'SELECT uid, numero, titre, sort FROM amendements WHERE dossier_ref = ? ORDER BY numero, uid',
    params = list(uid), cache = cache)
  esc = function(x) .echapper_latex(as.character(x))
  tableau = function(x, noms, vide) {
    if (!nrow(x)) return(vide)
    names(x) = noms
    x[] = lapply(x, function(v) { v = as.character(v); v[is.na(v)] = ''; v })
    knitr::kable(x, format = 'latex', booktabs = TRUE, longtable = TRUE, escape = TRUE)
  }
  lignes = c(
    paste0('\\begin{center}\\Large\\bfseries ', esc(titre), '\\par\\end{center}'),
    paste0('\\noindent\\textbf{Dossier officiel AN :} ', esc(uid)),
    '\\section*{Comprendre le parcours d\'une loi}',
    paste('Un projet ou une proposition de loi est depose, examine en commission',
          'puis discute et vote en seance. Les deux chambres peuvent examiner',
          'successivement le texte (navette parlementaire). L\'adoption definitive',
          'ne signifie pas encore promulgation. Le parcours varie selon la procedure.'),
    '\\section*{Ce que montre ce dossier}',
    paste0('\\textbf{Documents references :} ', length(refs),
           ' (references AN : ', length(an), '; references Senat : ', length(senat), ').'),
    paste0('\\textbf{Reunions liees par un point d\'ordre du jour :} ', nrow(reunions), '.'),
    paste0('\\textbf{Amendements directement rattaches :} ', nrow(amendements), '.'),
    '\\section*{Documents des deux chambres}',
    tableau(data.frame(chambre = ifelse(grepl('SNR', refs, fixed = TRUE), 'Senat',
                                      ifelse(grepl('ANR', refs, fixed = TRUE), 'AN', 'Autre')),
                       reference = refs), c('Chambre', 'Reference officielle'),
            'Aucune reference complete disponible.'),
    '\\section*{Chronologie des reunions rattachees}',
    tableau(reunions[, c('debut', 'organe_ref', 'objet', 'compte_rendu_ref'), drop = FALSE],
            c('Date', 'Organe', 'Objet', 'Compte rendu (reference)'),
            'Aucune reunion rattachee dans la base locale.'),
    '\\section*{Amendements rattaches}',
    tableau(utils::head(amendements[, c('numero', 'titre', 'sort'), drop = FALSE], 30L),
            c('Numero', 'Intitule', 'Sort'),
            'Aucun amendement rattache dans la base locale.'),
    if (nrow(amendements) > 30L)
      paste0('Seuls les 30 premiers amendements sur ', nrow(amendements), ' sont affiches.'),
    '\\section*{Lire les donnees avec prudence}',
    paste('Une reference de texte senatorial atteste un document associe,',
          'pas la disponibilite de tous les debats ou votes du Senat.',
          'Les comptes rendus de commission et les scrutins ne sont pas',
          'attribues automatiquement au dossier sans lien officiel verifie.',
          'DOLE et DOSLEG restent des sources a integrer.'),
    '\\noindent\\textit{Source : donnees officielles de l\'Assemblee nationale, base locale assembleer.}'
  )
  lignes = lignes[!is.na(lignes)]
  chemin = .pdf_assembleer('Comprendre la vie democratique',
                            uid, paste(lignes, collapse = '\n\n'), sortie, modele = modele)
  if (isTRUE(ouvrir)) {
    commande = Sys.which('xdg-open')
    if (nzchar(commande)) system2(commande, shQuote(chemin), wait = FALSE)
  }
  invisible(chemin)
}
