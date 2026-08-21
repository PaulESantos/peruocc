#' Configura el directorio de trabajo de `peruocc`
#'
#' Define el directorio raíz donde el paquete guarda resultados exportados y,
#' cuando se configura explícitamente, los límites y checkpoints de consultas.
#' La configuración se conserva durante la sesión de R mediante la opción
#' `peruocc.data_dir`; no modifica archivos de configuración permanentes.
#'
#' @param path Cadena de longitud uno con una ruta existente o por crear. Debe
#'   apuntar a una ubicación con permisos de escritura. Si es `NULL`, usa la
#'   opción ya configurada y, si no existe, crea `peruocc/` bajo el directorio
#'   de trabajo actual.
#' @return Invisiblemente, la ruta absoluta normalizada que quedó activa.
#' @details Los resultados se escriben en `processed/` y los límites o
#' checkpoints en `cache/` dentro de este directorio. Configure una ruta fuera
#' del repositorio cuando ejecute viñetas o análisis reproducibles para evitar
#' incorporar artefactos generados al paquete.
#' @examples
#' dir_temporal <- file.path(tempdir(), "peruocc-ejemplo")
#' peruocc_data_dir(dir_temporal)
#' # consultar la ruta activa:
#' peruocc_data_dir()
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
    tolerancia_simplificacion_m = 100,
    max_area_ha_por_lote = 1000,
    reintentos_api = 3L,
    pausa_entre_lotes_s = 0.2
  )
}
