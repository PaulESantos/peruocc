# zzz.R
# Carga de dependencias del nucleo y visualizacion de banner de arranque al estilo tidyverse.

core <- c(
  "sf",
  "rgbif",
  "rinat",
  "geoperu"
)

core_unloaded <- function() {
  search <- paste0("package:", core)
  core[!search %in% search()]
}

# Adjuntar el paquete desde la misma libreria de donde fue cargado
same_library <- function(pkg) {
  loc <- if (pkg %in% loadedNamespaces()) dirname(getNamespaceInfo(pkg, "path")) else NULL
  if (!is.null(loc)) {
    library(pkg, lib.loc = loc, character.only = TRUE, warn.conflicts = FALSE)
  } else {
    library(pkg, character.only = TRUE, warn.conflicts = FALSE)
  }
}

peruocc_attach <- function() {
  to_load <- core_unloaded()

  suppressPackageStartupMessages(
    lapply(to_load, same_library)
  )

  invisible(to_load)
}

peruocc_attach_message <- function(to_load) {
  if (length(to_load) == 0) {
    return(NULL)
  }

  header <- cli::rule(
    left = cli::style_bold("Cargando peruocc"),
    right = paste0("v", package_version_h("peruocc"))
  )

  to_load <- sort(to_load)
  versions <- vapply(to_load, package_version_h, character(1))

  # Descripciones de rol de cada motor base
  descripciones <- c(
    geoperu = "L\u00edmites cartogr\u00e1ficos oficiales del Per\u00fa",
    rgbif   = "Extracci\u00f3n de ocurrencias desde GBIF",
    rinat   = "Observaciones ciudadanas de iNaturalist",
    sf      = "Operaciones geom\u00e9tricas y filtros espaciales"
  )

  desc_text <- descripciones[to_load]
  desc_text[is.na(desc_text)] <- ""

  max_name_len <- max(cli::ansi_nchar(to_load))
  max_ver_len  <- max(cli::ansi_nchar(versions))

  lineas <- vapply(seq_along(to_load), function(i) {
    pkg <- to_load[i]
    ver <- versions[i]
    desc <- desc_text[i]

    paste0(
      cli::col_green(cli::symbol$tick),
      " ",
      cli::col_blue(format(pkg, width = max_name_len)),
      " ",
      cli::ansi_align(ver, max_ver_len),
      if (nzchar(desc)) paste0("  ", cli::col_grey(paste0(cli::symbol$bullet, " ", desc))) else ""
    )
  }, character(1))

  paste0(header, "\n", paste(lineas, collapse = "\n"))
}

package_version_h <- function(pkg) {
  ver <- tryCatch(utils::packageVersion(pkg), error = function(e) "0.1.0")
  highlight_version(ver)
}

highlight_version <- function(x) {
  x <- as.character(x)

  is_dev <- function(x) {
    x <- suppressWarnings(as.numeric(x))
    !is.na(x) & x >= 9000
  }

  pieces <- strsplit(x, ".", fixed = TRUE)
  pieces <- lapply(pieces, function(x) ifelse(is_dev(x), cli::col_red(x), x))
  vapply(pieces, paste, collapse = ".", FUN.VALUE = character(1))
}

inform_startup <- function(msg, ...) {
  if (is.null(msg)) {
    return(invisible())
  }
  if (isTRUE(getOption("peruocc.quiet"))) {
    return(invisible())
  }
  packageStartupMessage(msg, ...)
}

.onAttach <- function(...) {
  if (is_loading_for_tests()) {
    return(invisible())
  }

  attached <- peruocc_attach()
  inform_startup(peruocc_attach_message(attached))
}

is_attached <- function(x) {
  paste0("package:", x) %in% search()
}

is_loading_for_tests <- function() {
  identical(Sys.getenv("DEVTOOLS_LOAD"), "peruocc") ||
  identical(Sys.getenv("TESTTHAT"), "true") ||
  nzchar(Sys.getenv("R_TESTS"))
}
