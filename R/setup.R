# Verificacion de dependencias del paquete.
paquetes_requeridos <- c("cli", "sf", "rgbif", "rinat", "ggplot2", "dplyr", "readr", "jsonlite", "geoperu")

#' Verifica las dependencias de `peruocc`
#'
#' Comprueba la disponibilidad de los paquetes requeridos para límites
#' administrativos, operaciones espaciales, consultas a GBIF/iNaturalist,
#' visualización y exportación. Úsela al preparar una instalación nueva o para
#' diagnosticar un error de carga.
#'
#' @return Invisiblemente `TRUE` si todas las dependencias están disponibles.
#' @examples
#' verificar_y_configurar_entorno()
#' @export
verificar_y_configurar_entorno <- function() {
  faltantes <- paquetes_requeridos[!vapply(paquetes_requeridos, requireNamespace, logical(1), quietly = TRUE)]
  if (length(faltantes) > 0) {
    cli::cli_abort(c(
      "x" = "Faltan paquetes requeridos: {.pkg {faltantes}}.",
      "i" = "Por favor, instale las dependencias faltantes para continuar."
    ))
  }
  cli::cli_alert_success("Todas las dependencias requeridas est\u00e1n disponibles.")
  invisible(TRUE)
}
