#' Configura el directorio de trabajo de `peruocc`
#'
#' Define el directorio raíz donde el paquete guarda resultados exportados y,
#' cuando se configura explícitamente, los límites y checkpoints de consultas.
#' La configuración se conserva durante la sesión de R mediante la opción
#' `peruocc.data_dir`; no modifica archivos de configuración permanentes ni crea
#' directorios por defecto en el espacio de trabajo del usuario.
#'
#' @param path Cadena de longitud uno con una ruta existente o por crear. Debe
#'   apuntar a una ubicación con permisos de escritura. Si es `NULL`, devuelve la
#'   ruta configurada actualmente (o `NULL` si no se ha configurado ninguna).
#' @return Invisiblemente, la ruta absoluta normalizada activa, o `NULL` si no
#'   se ha definido un directorio.
#' @details Cuando está configurado, los resultados se escriben en `processed/`
#' y los checkpoints en `cache/` dentro de este directorio.
#' @examples
#' dir_temporal <- file.path(tempdir(), "peruocc-ejemplo")
#' peruocc_data_dir(dir_temporal)
#' # consultar la ruta activa:
#' peruocc_data_dir()
#' @export
peruocc_data_dir <- function(path = NULL) {
  if (is.null(path)) {
    return(getOption("peruocc.data_dir", getOption("peruspecies.data_dir", NULL)))
  }
  if (!is.character(path) || length(path) != 1L || !nzchar(trimws(path))) {
    cli::cli_abort("{.arg path} debe ser una cadena de texto no vac\u00eda.")
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
  if (is.null(user_dir)) {
    return(NULL)
  }
  dir_cache <- file.path(user_dir, "cache")
  dir.create(dir_cache, recursive = TRUE, showWarnings = FALSE)
  file.path(dir_cache, ...)
}

ruta_peruocc <- function(...) {
  base_dir <- peruocc_data_dir()
  if (is.null(base_dir)) {
    return(NULL)
  }
  file.path(base_dir, ...)
}

ruta_peruspecies <- function(...) {
  ruta_peruocc(...)
}

configuracion_predeterminada <- function() {
  list(
    limite_por_api = 500L,
    tolerancia_simplificacion_m = 100,
    max_area_ha_por_lote = 1000,
    max_lotes_espaciales = 16L,
    umbral_macro_bloques_ha = 50000,
    reintentos_api = 3L,
    pausa_entre_lotes_s = 0.2
  )
}
