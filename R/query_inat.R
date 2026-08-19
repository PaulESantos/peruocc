# query_inat.R
# Funciones para consultar ocurrencias de especies en la base de datos de iNaturalist con filtro espacial.

#' Busca ocurrencias de especies en iNaturalist dentro de un poligono de distrito o provincia
#'
#' @param poligono_sf Objeto sf que representa la unidad espacial (EPSG:4326).
#' @param query Texto libre de busqueda (opcional).
#' @param taxon_name Nombre de la especie o grupo taxonomico (opcional).
#' @param grupo Grupo taxonomico: "flora", "fauna" o NULL.
#' @param calidad Grado de calidad: "research" (por defecto), "casual" o NULL (ambos).
#' @param limite Numero maximo de registros a recuperar (max. 10000 para get_inat_obs).
#' @return Un dataframe estandarizado con los registros encontrados que caen dentro del poligono.
buscar_inat_por_poligono <- function(poligono_sf, 
                                     query = NULL, 
                                     taxon_name = NULL, 
                                     grupo = NULL, 
                                     calidad = "research", 
                                     limite = 500) {
  
  cat("[iNaturalist] Iniciando busqueda de ocurrencias...\n")
  
  # Obtener nombres administrativos para registrar en el dataset
  nombre_distrito <- if (!is.null(poligono_sf$distrito) && !is.na(poligono_sf$distrito[1])) poligono_sf$distrito[1] else NA_character_
  nombre_provincia <- if (!is.null(poligono_sf$provincia) && !is.na(poligono_sf$provincia[1])) poligono_sf$provincia[1] else NA_character_
  nombre_departamento <- if (!is.null(poligono_sf$departamento) && !is.na(poligono_sf$departamento[1])) poligono_sf$departamento[1] else NA_character_
  etiqueta_unidad <- if (!is.na(nombre_distrito)) nombre_distrito else if (!is.na(nombre_provincia)) nombre_provincia else "Unidad seleccionada"
  
  # 1. Obtener el Bounding Box del poligono
  bbox <- sf::st_bbox(poligono_sf)
  bbox_vector <- c(bbox["ymin"], bbox["xmin"], bbox["ymax"], bbox["xmax"])
  
  # 2. Configurar filtros de taxon y grupo
  taxon_query <- taxon_name
  
  if (is.null(taxon_query) && !is.null(grupo)) {
    grupo_clean <- tolower(trimws(grupo))
    if (grupo_clean == "flora") {
      taxon_query <- "Plantae"
      cat("[iNaturalist] Filtrando por reino Plantae (Flora).\n")
    } else if (grupo_clean == "fauna") {
      taxon_query <- "Animalia"
      cat("[iNaturalist] Filtrando por reino Animalia (Fauna).\n")
    }
  }
  
  # 3. Consultar a iNaturalist usando el Bounding Box
  limite_etiqueta <- if (is.null(limite)) "completo" else as.character(limite)
  cat(sprintf("[iNaturalist] Consultando registros dentro de la caja delimitadora de '%s' (limite: %s)...\n", etiqueta_unidad, limite_etiqueta))
  
  parametros <- list(
    bounds = bbox_vector,
    geo = TRUE
  )
  
  if (!is.null(query) && query != "") {
    parametros$query <- query
  }
  if (!is.null(taxon_query) && taxon_query != "") {
    parametros$taxon_name <- taxon_query
  }
  if (!is.null(calidad) && calidad != "") {
    parametros$quality <- calidad
  }
  
  total_api <- NA_integer_
  if (is.null(limite)) {
    metadatos <- tryCatch(do.call(rinat::get_inat_obs, c(parametros, list(maxresults = 1, meta = TRUE))), error = function(e) NULL)
    total_api <- if (!is.null(metadatos$meta$found)) as.integer(metadatos$meta$found) else NA_integer_
    if (is.na(total_api)) stop("iNaturalist no devolvio el conteo de la consulta; no es posible verificar una descarga completa.")
    if (total_api > 10000L) stop(sprintf("iNaturalist reporta %s registros. El cliente rinat solo descarga hasta 10000 por consulta; use la exportacion oficial de iNaturalist o divida la extraccion por periodos antes de combinarla.", format(total_api, big.mark = ",")))
    parametros$maxresults <- total_api
  } else {
    parametros$maxresults <- limite
  }
  
  obs_raw <- tryCatch({
    do.call(rinat::get_inat_obs, parametros)
  }, error = function(e) {
    cat("[iNaturalist] Error durante la llamada a get_inat_obs: ", e$message, "\n")
    return(NULL)
  })
  
  df_vacio <- schema_ocurrencias()
  
  if (is.null(obs_raw) || nrow(obs_raw) == 0) {
    cat("[iNaturalist] No se encontraron ocurrencias en la caja delimitadora.\n")
    attr(df_vacio, "api_total") <- if (is.na(total_api)) 0L else total_api
    attr(df_vacio, "api_complete") <- is.null(limite) && !is.na(total_api)
    return(df_vacio)
  }
  
  cat(sprintf("[iNaturalist] Se descargaron %d registros en la caja delimitadora. Aplicando filtro espacial...\n", nrow(obs_raw)))
  
  # 4. Filtro Espacial (Interseccion con el poligono exacto)
  obs_sf <- sf::st_as_sf(obs_raw, coords = c("longitude", "latitude"), crs = 4326, remove = FALSE)
  poligono_exacto <- sf::st_make_valid(poligono_sf)
  obs_sf <- sf::st_make_valid(obs_sf)
  
  interseccion <- sf::st_intersects(obs_sf, poligono_exacto, sparse = FALSE)
  obs_dentro <- obs_sf[interseccion[, 1], ]
  
  if (nrow(obs_dentro) == 0) {
    cat("[iNaturalist] Ninguno de los registros se encuentra estrictamente dentro del poligono seleccionado.\n")
    return(df_vacio)
  }
  
  datos_raw <- sf::st_drop_geometry(obs_dentro)
  
  # 5. Estandarizar columnas de salida
  datos_procesados <- schema_ocurrencias()[rep(1, nrow(datos_raw)), ]
  
  datos_procesados$scientificName <- if ("scientific_name" %in% colnames(datos_raw)) datos_raw$scientific_name else as.character(NA)
  datos_procesados$decimalLatitude <- if ("latitude" %in% colnames(datos_raw)) as.numeric(datos_raw$latitude) else as.numeric(NA)
  datos_procesados$decimalLongitude <- if ("longitude" %in% colnames(datos_raw)) as.numeric(datos_raw$longitude) else as.numeric(NA)
  
  if ("observed_on" %in% colnames(datos_raw)) {
    datos_procesados$eventDate <- as.character(datos_raw$observed_on)
  } else if ("datetime" %in% colnames(datos_raw)) {
    datos_procesados$eventDate <- as.character(datos_raw$datetime)
  } else {
    datos_procesados$eventDate <- as.character(NA)
  }
  
  datos_procesados$taxonRank <- if ("rank" %in% colnames(datos_raw)) datos_raw$rank else as.character(NA)
  
  if (!is.null(grupo)) {
    grupo_clean <- tolower(trimws(grupo))
    datos_procesados$kingdom <- ifelse(grupo_clean == "flora", "Plantae", ifelse(grupo_clean == "fauna", "Animalia", as.character(NA)))
  } else {
    if (!is.null(taxon_query)) {
      if (taxon_query == "Plantae") datos_procesados$kingdom <- "Plantae"
      else if (taxon_query == "Animalia") datos_procesados$kingdom <- "Animalia"
      else datos_procesados$kingdom <- as.character(NA)
    } else {
      datos_procesados$kingdom <- as.character(NA)
    }
  }
  
  datos_procesados$phylum <- as.character(NA)
  datos_procesados$class <- as.character(NA)
  datos_procesados$order <- as.character(NA)
  datos_procesados$family <- as.character(NA)
  datos_procesados$genus <- as.character(NA)
  datos_procesados$species <- as.character(NA)
  
  datos_procesados$recordedBy <- if ("user_login" %in% colnames(datos_raw)) datos_raw$user_login else as.character(NA)
  datos_procesados$coordinateUncertaintyInMeters <- if ("positional_accuracy" %in% colnames(datos_raw)) as.numeric(datos_raw$positional_accuracy) else as.numeric(NA)
  datos_procesados$sourceRecordID <- as.character(valor_columna(datos_raw, "id"))
  datos_procesados$occurrenceID <- ifelse(is.na(datos_procesados$sourceRecordID), NA_character_, paste0("https://www.inaturalist.org/observations/", datos_procesados$sourceRecordID))
  datos_procesados$sourceURL <- datos_procesados$occurrenceID
  datos_procesados$license <- as.character(valor_columna(datos_raw, "license"))
  datos_procesados$basisOfRecord <- "HumanObservation"
  
  datos_procesados$source <- "iNaturalist"
  datos_procesados$district <- nombre_distrito
  datos_procesados$province <- nombre_provincia
  datos_procesados$department <- nombre_departamento
  
  cat(sprintf("[iNaturalist] Busqueda finalizada. %d de %d registros caen dentro del poligono seleccionado.\n",
              nrow(datos_procesados), nrow(obs_raw)))
  attr(datos_procesados, "api_total") <- total_api
  attr(datos_procesados, "api_complete") <- is.null(limite) && !is.na(total_api) && nrow(obs_raw) == total_api
  
  return(datos_procesados)
}
