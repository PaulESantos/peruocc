#' Configure the directory used for package artifacts
#'
#' Sets the root directory used for cached boundaries, processed data, and
#' figures. By default this is a `peruocc` subdirectory in the current
#' working directory.
#'
#' @param path Existing or new writable directory.
#' @return The normalized path, invisibly.
#' @export
peruocc_data_dir <- function(path = NULL) {
  if (is.null(path)) {
    path <- getOption("peruocc.data_dir", getOption("peruspecies.data_dir", file.path(getwd(), "peruocc")))
  }
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  options(peruocc.data_dir = path)
  invisible(path)
}

#' @rdname peruocc_data_dir
#' @export
peruspecies_data_dir <- function(path = NULL) {
  .Deprecated("peruocc_data_dir")
  peruocc_data_dir(path = path)
}

ruta_peruocc <- function(...) {
  file.path(peruocc_data_dir(), ...)
}

ruta_peruspecies <- function(...) {
  ruta_peruocc(...)
}

configuracion_predeterminada <- function() {
  list(
    limite_por_api = 500L,
    tolerancia_simplificacion_m = 100
  )
}
