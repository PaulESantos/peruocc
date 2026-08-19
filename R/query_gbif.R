# query_gbif.R
# Funciones para consultar ocurrencias de especies en la base de datos de GBIF.

#' Busca ocurrencias de especies en GBIF dentro de un poligono de distrito o provincia
#'
#' @param poligono_sf Objeto sf que representa la unidad espacial (EPSG:4326).
#' @param nombre_cientifico Nombre de la especie o grupo taxonomico (opcional).
#' @param grupo Grupo taxonomico: "flora", "fauna" o NULL.
#' @param limite Numero maximo de registros a recuperar (max. 100000 para occ_search).
#' @param tolerancia_simplificacion Tolerancia de simplificacion en metros (def: 100 metros).
#' @return Un dataframe estandarizado con los registros encontrados.
buscar_gbif_por_poligono <- function(poligono_sf, 
                                     nombre_cientifico = NULL, 
                                     grupo = NULL, 
                                     limite = 500, 
                                     tolerancia_simplificacion = 100) {
  
  cat("[GBIF] Iniciando busqueda de ocurrencias...\n")
  
  # 1. Simplificar el poligono de manera inteligente para la API (limite de longitud WKT <= 1500)
  poligono_api <- simplificar_para_api(poligono_sf, tolerancia_inicial_metros = tolerancia_simplificacion)
  wkt <- poligono_a_wkt(poligono_api)
  
  # Obtener nombres administrativos para registrar en el dataset
  nombre_distrito <- if (!is.null(poligono_sf$distrito) && !is.na(poligono_sf$distrito[1])) poligono_sf$distrito[1] else NA_character_
  nombre_provincia <- if (!is.null(poligono_sf$provincia) && !is.na(poligono_sf$provincia[1])) poligono_sf$provincia[1] else NA_character_
  nombre_departamento <- if (!is.null(poligono_sf$departamento) && !is.na(poligono_sf$departamento[1])) poligono_sf$departamento[1] else NA_character_
  etiqueta_unidad <- if (!is.na(nombre_distrito)) nombre_distrito else if (!is.na(nombre_provincia)) nombre_provincia else "Unidad seleccionada"
  
  # 2. Configurar filtros taxonomicos
  taxon_key <- NULL
  if (!is.null(nombre_cientifico) && nombre_cientifico != "") {
    cat(sprintf("[GBIF] Resolviendo taxonomia para '%s'...\n", nombre_cientifico))
    resolucion <- tryCatch({
      rgbif::name_backbone(name = nombre_cientifico)
    }, error = function(e) {
      cat("[GBIF] Advertencia: No se pudo conectar al resolutor taxonomico de GBIF.\n")
      return(NULL)
    })
    
    if (!is.null(resolucion) && resolucion$matchType != "NONE") {
      taxon_key <- resolucion$usageKey
      cat(sprintf("[GBIF] Taxon resuelto: %s (Key: %s, Rank: %s)\n", 
                  resolucion$scientificName, as.character(taxon_key), resolucion$rank))
    } else {
      cat(sprintf("[GBIF] Advertencia: No se encontro coincidencia taxonomica para '%s'. Se buscara por texto libre.\n", nombre_cientifico))
    }
  }
  
  # Configurar filtro de grupo (Reino)
  # Reino Plantae = 6, Animalia = 1
  kingdom_key <- NULL
  if (!is.null(grupo)) {
    grupo_clean <- tolower(trimws(grupo))
    if (grupo_clean == "flora") {
      kingdom_key <- 6
      cat("[GBIF] Filtrando por reino Plantae (Flora).\n")
    } else if (grupo_clean == "fauna") {
      kingdom_key <- 1
      cat("[GBIF] Filtrando por reino Animalia (Fauna).\n")
    }
  }
  
  # 3. Ejecutar consulta
  limite_etiqueta <- if (is.null(limite)) "completo" else as.character(limite)
  cat(sprintf("[GBIF] Consultando registros dentro del poligono de '%s' (limite: %s)...\n", etiqueta_unidad, limite_etiqueta))
  
  parametros <- list(
    geometry = wkt,
    hasCoordinate = TRUE
  )
  
  if (!is.null(taxon_key)) {
    parametros$taxonKey <- taxon_key
  }
  if (!is.null(kingdom_key)) {
    parametros$kingdomKey <- kingdom_key
  }
  
  if (is.null(taxon_key) && !is.null(nombre_cientifico) && nombre_cientifico != "") {
    parametros$scientificName <- nombre_cientifico
  }

  total_api <- NA_integer_
  if (is.null(limite)) {
    conteo <- tryCatch(do.call(rgbif::occ_search, c(parametros, list(limit = 0))), error = function(e) NULL)
    total_api <- if (!is.null(conteo$meta$count)) as.integer(conteo$meta$count) else NA_integer_
    if (is.na(total_api)) stop("GBIF no devolvio el conteo de la consulta; no es posible verificar una descarga completa.")
    if (total_api > 100000L) stop(sprintf("GBIF reporta %s registros. occ_search solo permite 100000; solicite una descarga masiva citable con rgbif::occ_download() usando los mismos filtros.", format(total_api, big.mark = ",")))
    parametros$limit <- total_api
  } else {
    parametros$limit <- limite
  }
  
  res <- tryCatch({
    do.call(rgbif::occ_search, parametros)
  }, error = function(e) {
    cat("[GBIF] Error durante la llamada a occ_search: ", e$message, "\n")
    return(NULL)
  })
  
  df_vacio <- schema_ocurrencias()
  
  if (is.null(res) || is.null(res$data) || nrow(res$data) == 0) {
    cat("[GBIF] No se encontraron ocurrencias.\n")
    attr(df_vacio, "api_total") <- if (is.na(total_api)) 0L else total_api
    attr(df_vacio, "api_complete") <- is.null(limite) && !is.na(total_api)
    return(df_vacio)
  }
  
  datos_raw <- res$data
  
  # 4. Estandarizar columnas de salida
  columnas_mapeo <- list(
    occurrenceID = "key",
    sourceRecordID = "key",
    datasetKey = "datasetKey",
    license = "license",
    basisOfRecord = "basisOfRecord",
    scientificName = "scientificName",
    decimalLatitude = "decimalLatitude",
    decimalLongitude = "decimalLongitude",
    eventDate = "eventDate",
    taxonRank = "taxonRank",
    kingdom = "kingdom",
    phylum = "phylum",
    class = "class",
    order = "order",
    family = "family",
    genus = "genus",
    species = "species",
    recordedBy = "recordedBy",
    coordinateUncertaintyInMeters = "coordinateUncertaintyInMeters"
  )
  
  datos_procesados <- schema_ocurrencias()[rep(1, nrow(datos_raw)), ]
  
  for (col in names(columnas_mapeo)) {
    col_raw <- columnas_mapeo[[col]]
    if (col_raw %in% colnames(datos_raw)) {
      datos_procesados[[col]] <- datos_raw[[col_raw]]
    } else {
      if (col %in% c("decimalLatitude", "decimalLongitude", "coordinateUncertaintyInMeters")) {
        datos_procesados[[col]] <- as.numeric(NA)
      } else {
        datos_procesados[[col]] <- as.character(NA)
      }
    }
  }
  datos_procesados$sourceURL <- ifelse(is.na(datos_procesados$sourceRecordID), NA_character_, paste0("https://www.gbif.org/occurrence/", datos_procesados$sourceRecordID))
  
  if ("eventDate" %in% colnames(datos_procesados)) {
    datos_procesados$eventDate <- as.character(datos_procesados$eventDate)
  }
  
  datos_procesados$source <- "GBIF"
  datos_procesados$district <- nombre_distrito
  datos_procesados$province <- nombre_provincia
  datos_procesados$department <- nombre_departamento
  
  # 5. Filtrar espacialmente con el poligono exacto (poligono_sf) en R
  if (nrow(datos_procesados) > 0) {
    ocurrencias_sf <- tryCatch({
      sf::st_as_sf(datos_procesados[is.finite(datos_procesados$decimalLongitude) & is.finite(datos_procesados$decimalLatitude), ], coords = c("decimalLongitude", "decimalLatitude"), crs = 4326, remove = FALSE)
    }, error = function(e) {
      NULL
    })
    
    if (!is.null(ocurrencias_sf)) {
      poligono_exacto <- sf::st_make_valid(poligono_sf)
      ocurrencias_sf <- sf::st_make_valid(ocurrencias_sf)
      interseccion <- sf::st_intersects(ocurrencias_sf, poligono_exacto, sparse = FALSE)
      datos_procesados <- sf::st_drop_geometry(ocurrencias_sf[interseccion[, 1], ])
    }
  }
  
  cat(sprintf("[GBIF] Busqueda finalizada. Se filtraron %d registros que caen dentro del poligono seleccionado.\n", nrow(datos_procesados)))
  attr(datos_procesados, "api_total") <- if (is.na(total_api)) res$meta$count else total_api
  attr(datos_procesados, "api_complete") <- is.null(limite) && !is.na(total_api) && nrow(res$data) == total_api
  
  return(datos_procesados)
}
