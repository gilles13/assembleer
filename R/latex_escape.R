# Echappement des caracteres reserves de LaTeX, sans modifier Unicode.
.echapper_latex = function(x) {
  x = as.character(x)
  substitutions = c(
    "\\" = "\\textbackslash{}",
    "{" = "\\{", "}" = "\\}",
    "$" = "\\$", "&" = "\\&", "#" = "\\#",
    "%" = "\\%", "_" = "\\_",
    "~" = "\\textasciitilde{}", "^" = "\\textasciicircum{}"
  )
  vapply(x, function(texte) {
    if (is.na(texte)) return(NA_character_)
    caracteres = strsplit(texte, "", fixed = TRUE)[[1L]]
    positions = match(caracteres, names(substitutions))
    remplacer = !is.na(positions)
    caracteres[remplacer] = unname(substitutions[positions[remplacer]])
    paste0(caracteres, collapse = "")
  }, character(1), USE.NAMES = FALSE)
}
