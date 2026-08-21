# Verificacion de dependencias del paquete.
paquetes_requeridos <- c("sf", "rgbif", "rinat", "ggplot2", "dplyr", "readr", "jsonlite", "geoperu")

#' Verifica y, opcionalmente, instala las dependencias de `peruocc`
#'
#' Comprueba la disponibilidad de los paquetes requeridos para límites
#' administrativos, operaciones espaciales, consultas a GBIF/iNaturalist,
#' visualización y exportación. Úsela al preparar una instalación nueva o para
#' diagnosticar un error de carga.
#'
#' @param instalar Lógico de longitud uno. Con `FALSE` (predeterminado) informa
#'   los paquetes faltantes mediante un error, sin cambiar el sistema. Con
#'   `TRUE` intenta instalarlos desde el repositorio configurado de R; requiere
#'   conexión a Internet y permisos de escritura en la biblioteca de paquetes.
#' @return Invisiblemente `TRUE` si todas las dependencias están disponibles.
#' @examples
#' \dontrun{
#' verificar_y_configurar_entorno()
#' verificar_y_configurar_entorno(instalar = TRUE)
#' }
#' @export
verificar_y_configurar_entorno <- function(instalar = FALSE) {
  faltantes <- paquetes_requeridos[!vapply(paquetes_requeridos, requireNamespace, logical(1), quietly = TRUE)]
  if (length(faltantes) && !instalar) {
    stop("Faltan paquetes: ", paste(faltantes, collapse = ", "),
         ". Instale el paquete con sus dependencias o restaure el entorno con renv::restore().")
  }
  if (length(faltantes)) utils::install.packages(faltantes, repos = "https://cloud.r-project.org", dependencies = TRUE)
  invisible(TRUE)
}
