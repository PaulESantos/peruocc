# Internal helpers for validation, schemas, and run manifests.

schema_ocurrencias <- function() {
  data.frame(
    occurrenceID = character(),
    sourceRecordID = character(),
    sourceURL = character(),
    datasetKey = character(),
    license = character(),
    basisOfRecord = character(),
    scientificName = character(),
    decimalLatitude = numeric(),
    decimalLongitude = numeric(),
    eventDate = character(),
    taxonRank = character(),
    kingdom = character(),
    phylum = character(),
    class = character(),
    order = character(),
    family = character(),
    genus = character(),
    species = character(),
    recordedBy = character(),
    coordinateUncertaintyInMeters = numeric(),
    source = character(),
    district = character(),
    province = character(),
    department = character(),
    stringsAsFactors = FALSE
  )
}

valor_columna <- function(datos, nombre, tipo = "character") {
  if (nombre %in% names(datos)) {
    return(datos[[nombre]])
  }

  if (tipo == "numeric") {
    rep(NA_real_, nrow(datos))
  } else {
    rep(NA_character_, nrow(datos))
  }
}

validar_entrada_busqueda <- function(unidad, grupo = NULL, limite = NULL, nivel = "distrito") {
  if (!is.character(unidad) || length(unidad) != 1L || !nzchar(trimws(unidad))) {
    stop(sprintf("'%s' debe ser un texto no vacio.", nivel))
  }

  if (!is.null(grupo) && !tolower(grupo) %in% c("flora", "fauna")) {
    stop("'grupo' debe ser 'flora', 'fauna' o NULL.")
  }

  if (is.null(limite)) {
    return(invisible(TRUE))
  }

  if (!is.numeric(limite) || length(limite) != 1L || is.na(limite) ||
      limite < 1 || limite > 10000 || limite != as.integer(limite)) {
    stop("'limite_por_api' debe ser NULL o un entero entre 1 y 10000.")
  }

  invisible(TRUE)
}

crear_directorios_proyecto <- function() {
  for (ruta in c("raw", "cache", "processed", "results")) {
    dir.create(ruta_peruocc(ruta), recursive = TRUE, showWarnings = FALSE)
  }
}

versiones_paquetes <- function(paquetes = c(
  "sf", "rgbif", "rinat", "ggplot2", "dplyr", "readr", "jsonlite", "geoperu"
)) {
  versiones <- vapply(
    paquetes,
    function(paquete) {
      if (requireNamespace(paquete, quietly = TRUE)) {
        as.character(utils::packageVersion(paquete))
      } else {
        NA_character_
      }
    },
    character(1)
  )
  stats::setNames(versiones, paquetes)
}

escribir_manifiesto <- function(run_id, parametros, unidad_sf, resumen, archivos, ruta) {
  manifiesto <- list(
    schema_version = "1.0",
    run_id = run_id,
    executed_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
    parameters = parametros,
    spatial = list(
      crs = sf::st_crs(unidad_sf)$input,
      polygon_wkt = sf::st_as_text(sf::st_geometry(unidad_sf)[[1]])
    ),
    result_summary = resumen,
    files = archivos,
    runtime = list(
      r_version = R.version.string,
      packages = as.list(versiones_paquetes())
    )
  )

  jsonlite::write_json(
    manifiesto,
    ruta,
    pretty = TRUE,
    auto_unbox = TRUE,
    null = "null"
  )
}

#' Exporta los resultados de una busqueda de biodiversidad a disco
#'
#' Guarda los registros consolidados de ocurrencias en formatos CSV, capas
#' espaciales GeoJSON y un archivo de manifiesto JSON para trazabilidad y reproducibilidad.
#'
#' @param resultado Lista devuelta por `buscar_especies_peru()`, `buscar_especies_distrito()` o `buscar_especies_provincia()`.
#' @param dir_salida Directorio de destino donde se guardaran los archivos (por defecto el subdirectorio `processed/` de `peruocc_data_dir()`).
#' @param prefijo Prefijo opcional para nombrar los archivos. Si es NULL, se genera automaticamente.
#' @param formatos Vector con los formatos a generar: "csv", "geojson", "manifiesto".
#' @return Una lista invisible con las rutas de los archivos generados.
#' @export
exportar_resultados <- function(resultado, dir_salida = NULL, prefijo = NULL, formatos = c("csv", "geojson", "manifiesto")) {
  if (missing(resultado) || is.null(resultado) || !is.list(resultado)) {
    stop("Error: 'resultado' debe ser una lista valida generada por buscar_especies_*().")
  }
  
  ocurrencias <- resultado$ocurrencias
  unidad_sf <- if (!is.null(resultado$unidad_sf)) resultado$unidad_sf else resultado$distrito_sf
  resumen <- resultado$resumen
  parametros <- resultado$parametros
  
  if (is.null(ocurrencias) || nrow(ocurrencias) == 0) {
    message("[EXPORTAR] No hay ocurrencias para exportar.")
    return(invisible(list()))
  }
  
  if (is.null(dir_salida)) {
    dir_salida <- ruta_peruocc("processed")
  }
  dir.create(dir_salida, recursive = TRUE, showWarnings = FALSE)
  
  if (is.null(prefijo)) {
    nombre_u <- if (!is.null(resumen$unidad)) resumen$unidad else if (!is.null(resumen$distrito) && !is.na(resumen$distrito)) resumen$distrito else resumen$provincia
    u_clean <- gsub(" ", "_", tolower(normalizar_texto(nombre_u)))
    grupo_clean <- if (!is.null(parametros$grupo)) tolower(parametros$grupo) else "biodiversidad"
    nivel_clean <- if (!is.null(parametros$nivel)) parametros$nivel else "unidad"
    run_id <- sprintf("%s_%s_%s_%s", format(Sys.time(), tz = "UTC", "%Y%m%dT%H%M%SZ"), nivel_clean, u_clean, grupo_clean)
  } else {
    run_id <- prefijo
  }
  
  archivos_creados <- list()
  
  # 1. CSV
  if ("csv" %in% formatos) {
    ruta_csv <- file.path(dir_salida, sprintf("ocurrencias_%s.csv", run_id))
    tryCatch({
      readr::write_csv(ocurrencias, ruta_csv)
      cat(sprintf("[ARCHIVO] Registros tabulares guardados en: '%s'\n", ruta_csv))
      archivos_creados$csv <- ruta_csv
    }, error = function(e) {
      warning("[ARCHIVO] Error al exportar CSV: ", e$message)
    })
  }
  
  # 2. GeoJSON
  if ("geojson" %in% formatos) {
    ruta_geojson <- file.path(dir_salida, sprintf("ocurrencias_%s.geojson", run_id))
    tryCatch({
      ocurrencias_geo <- dplyr::filter(ocurrencias, is.finite(decimalLongitude), is.finite(decimalLatitude))
      if (nrow(ocurrencias_geo) > 0) {
        sf_guardar <- sf::st_as_sf(
          ocurrencias_geo,
          coords = c("decimalLongitude", "decimalLatitude"),
          crs = 4326,
          remove = FALSE
        )
        sf::st_write(sf_guardar, ruta_geojson, quiet = TRUE, delete_dsn = TRUE)
        cat(sprintf("[ARCHIVO] Capa espacial GeoJSON guardada en: '%s'\n", ruta_geojson))
        archivos_creados$geojson <- ruta_geojson
      }
    }, error = function(e) {
      warning("[SIG] Error al exportar GeoJSON: ", e$message)
    })
  }
  
  # 3. Manifiesto JSON
  if ("manifiesto" %in% formatos && !is.null(unidad_sf)) {
    ruta_manifiesto <- file.path(dir_salida, sprintf("manifiesto_%s.json", run_id))
    tryCatch({
      escribir_manifiesto(
        run_id = run_id,
        parametros = parametros,
        unidad_sf = unidad_sf,
        resumen = resumen,
        archivos = archivos_creados,
        ruta = ruta_manifiesto
      )
      cat(sprintf("[ARCHIVO] Manifiesto guardado en: '%s'\n", ruta_manifiesto))
      archivos_creados$manifiesto <- ruta_manifiesto
    }, error = function(e) {
      warning("[ARCHIVO] Error al exportar manifiesto: ", e$message)
    })
  }
  
  invisible(archivos_creados)
}
