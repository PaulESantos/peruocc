#' Configure the directory used for package artifacts
#'
#' Sets the root directory used for cached boundaries, processed data, and
#' figures. By default this is a `peruspecies` subdirectory in the current
#' working directory.
#'
#' @param path Existing or new writable directory.
#' @return The normalized path, invisibly.
#' @export
peruspecies_data_dir <- function(path = NULL) {
  if (is.null(path)) {
    path <- getOption("peruspecies.data_dir", file.path(getwd(), "peruspecies"))
  }
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  options(peruspecies.data_dir = path)
  invisible(path)
}

ruta_peruspecies <- function(...) {
  file.path(peruspecies_data_dir(), ...)
}

configuracion_predeterminada <- function() {
  list(
    limite_por_api = 500L,
    tolerancia_simplificacion_m = 100
  )
}
