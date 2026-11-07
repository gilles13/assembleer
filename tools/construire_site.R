# Construire le site et publier la cheatsheet HTML autonome.
pkgdown::build_site()
pkgload::load_all(".", quiet = TRUE)
produire_cheatsheet(file.path("docs", "cheatsheet.html"), ouvrir = FALSE)
stopifnot(file.exists(file.path("docs", "cheatsheet.html")))
