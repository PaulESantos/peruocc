# Utilidades para rutas, validación y manifiestos de reproducibilidad.
schema_ocurrencias <- function() {
  data.frame(occurrenceID = character(), sourceRecordID = character(), sourceURL = character(), datasetKey = character(), license = character(), basisOfRecord = character(), scientificName = character(), decimalLatitude = numeric(), decimalLongitude = numeric(), eventDate = character(), taxonRank = character(), kingdom = character(), phylum = character(), class = character(), order = character(), family = character(), genus = character(), species = character(), recordedBy = character(), coordinateUncertaintyInMeters = numeric(), source = character(), district = character(), stringsAsFactors = FALSE)
}
valor_columna <- function(datos, nombre, tipo = "character") { if (nombre %in% names(datos)) return(datos[[nombre]]); if (tipo == "numeric") rep(NA_real_, nrow(datos)) else rep(NA_character_, nrow(datos)) }
validar_entrada_busqueda <- function(distrito, grupo, limite) {
  if (!is.character(distrito) || length(distrito) != 1L || !nzchar(trimws(distrito))) stop("'distrito' debe ser un texto no vacío.")
  if (!is.null(grupo) && !tolower(grupo) %in% c("flora", "fauna")) stop("'grupo' debe ser 'flora', 'fauna' o NULL.")
  if (is.null(limite)) return(invisible(TRUE))
  if (!is.numeric(limite) || length(limite) != 1L || is.na(limite) || limite < 1 || limite > 10000 || limite != as.integer(limite)) stop("'limite_por_api' debe ser NULL (descarga completa) o un entero entre 1 y 10000.")
}
crear_directorios_proyecto <- function() for (ruta in c("data/raw", "data/cache", "data/processed", "results")) dir.create(ruta, recursive = TRUE, showWarnings = FALSE)
versiones_paquetes <- function(paquetes = c("sf", "rgbif", "rinat", "ggplot2", "dplyr", "readr", "jsonlite", "geoperu")) stats::setNames(vapply(paquetes, function(p) if (requireNamespace(p, quietly = TRUE)) as.character(utils::packageVersion(p)) else NA_character_, character(1)), paquetes)
escribir_manifiesto <- function(run_id, parametros, distrito_sf, resumen, archivos, ruta) {
  manifiesto <- list(schema_version = "1.0", run_id = run_id, executed_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE), parameters = parametros, spatial = list(crs = sf::st_crs(distrito_sf)$input, polygon_wkt = sf::st_as_text(sf::st_geometry(distrito_sf)[[1]])), result_summary = resumen, files = archivos, runtime = list(r_version = R.version.string, packages = as.list(versiones_paquetes())))
  jsonlite::write_json(manifiesto, ruta, pretty = TRUE, auto_unbox = TRUE, null = "null")
}
