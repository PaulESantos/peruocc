# Entorno reproducible: esta función nunca instala paquetes por defecto.
paquetes_requeridos <- c("sf", "rgbif", "rinat", "ggplot2", "dplyr", "readr", "jsonlite", "geoperu")

verificar_y_configurar_entorno <- function(instalar = FALSE) {
  if (!file.exists("renv.lock") && !instalar) {
    stop("No existe 'renv.lock'. En un entorno validado ejecute source('scripts/lock_environment.R') y versione el lockfile antes de analizar datos.")
  }
  faltantes <- paquetes_requeridos[!vapply(paquetes_requeridos, requireNamespace, logical(1), quietly = TRUE)]
  if (length(faltantes) && !instalar) {
    stop("Faltan paquetes: ", paste(faltantes, collapse = ", "),
         ". Restaure el entorno con renv::restore() o use instalar = TRUE de forma explícita.")
  }
  if (length(faltantes)) install.packages(faltantes, repos = "https://cloud.r-project.org", dependencies = TRUE)
  invisible(TRUE)
}
