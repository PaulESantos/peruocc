# Verificacion de dependencias del paquete.
paquetes_requeridos <- c("sf", "rgbif", "rinat", "ggplot2", "dplyr", "readr", "jsonlite", "geoperu")

#' Verify package dependencies
#'
#' @param instalar Whether to install missing dependencies explicitly.
#' @return `TRUE`, invisibly, when all dependencies are available.
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
