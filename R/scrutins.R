# Les objets JSON sont lus sans simplification par jsonlite.
.objets = function(x) {
  if (is.null(x)) return(list())
  if (!is.list(x)) return(list(x))
  if (!is.null(names(x))) return(list(x))
  x
}

.valeur = function(x) {
  if (is.null(x) || !length(x)) return(NA_character_)
  if (is.list(x)) {
    if (!is.null(x[["#text"]])) return(.valeur(x[["#text"]]))
    return(NA_character_)
  }
  as.character(x[[1L]])
}

.scrutin = function(x) if (!is.null(x$scrutin)) x$scrutin else x

