#' Configure the directory used for package artifacts
#'
#' Sets the root directory used for processed data and exported artifacts.
#' By default, boundaries are cached in a standard user cache directory
#' (`tools::R_user_dir("peruocc", which = "cache")`) and exported files in a
#' `peruocc` subdirectory in the current working directory.
#'
#' @param path Existing or new writable directory.
#' @return The normalized path, invisibly.
#' @export
peruocc_data_dir <- function(path = NULL) {
  if (is.null(path)) {
    path <- getOption("peruocc.data_dir", getOption("peruspecies.data_dir", NULL))
    if (is.null(path)) {
      path <- file.path(getwd(), "peruocc")
    }
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

ruta_cache <- function(...) {
  user_dir <- getOption("peruocc.data_dir", NULL)
  if (!is.null(user_dir)) {
    dir_cache <- file.path(user_dir, "cache")
  } else {
    dir_cache <- tools::R_user_dir("peruocc", which = "cache")
  }
  dir.create(dir_cache, recursive = TRUE, showWarnings = FALSE)
  file.path(dir_cache, ...)
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
