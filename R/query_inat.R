# query_inat.R
# Funciones para consultar ocurrencias de especies en la base de datos de iNaturalist con filtro espacial.

library(rinat)
library(dplyr)
library(sf)

source("R/spatial_utils.R")
source("R/project_utils.R")

#' Busca ocurrencias de especies en iNaturalist dentro de un polígono de distrito
#'
#' @param poligono_sf Objeto sf que representa el distrito (EPSG:4326).
#' @param query Texto libre de búsqueda (opcional).
#' @param taxon_name Nombre de la especie o grupo taxonómico (opcional).
#' @param grupo Grupo taxonómico: "flora", "fauna" o NULL.
#' @param calidad Grado de calidad: "research" (por defecto), "casual" o NULL (ambos).
#' @param limite Número máximo de registros a recuperar (máx. 10000 para get_inat_obs).
#' @return Un dataframe estandarizado con los registros encontrados que caen dentro del polígono.
buscar_inat_por_poligono <- function(poligono_sf, 
                                     query = NULL, 
                                     taxon_name = NULL, 
                                     grupo = NULL, 
                                     calidad = "research", 
                                     limite = 500) {
  
  cat("[iNaturalist] Iniciando búsqueda de ocurrencias...\n")
  
  # Obtener nombre del distrito para registrar en el dataset
  nombre_distrito <- ifelse(!is.null(poligono_sf$distrito), poligono_sf$distrito[1], "Desconocido")
  
  # 1. Obtener el Bounding Box del polígono
  bbox <- sf::st_bbox(poligono_sf)
  
  # El formato para rinat es: c(min_lat, min_lon, max_lat, max_lon)
  # que corresponde a: c(ymin, xmin, ymax, xmax)
  bbox_vector <- c(bbox["ymin"], bbox["xmin"], bbox["ymax"], bbox["xmax"])
  
  # 2. Configurar filtros de taxon y grupo
  taxon_query <- taxon_name
  
  # Si el usuario especifica grupo pero no taxon_name, usamos los reinos de iNaturalist
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
  cat(sprintf("[iNaturalist] Consultando registros dentro de la caja delimitadora de '%s' (límite: %s)...\n", nombre_distrito, limite_etiqueta))
  
  parametros <- list(
    bounds = bbox_vector,
    geo = TRUE # Sólo registros georreferenciados
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
  
  # rinat pagina internamente hasta 10 000 registros. Para descarga completa
  # verificamos primero el total del servidor y fallamos explícitamente si el
  # endpoint no puede entregarlo completo.
  total_api <- NA_integer_
  if (is.null(limite)) {
    metadatos <- tryCatch(do.call(rinat::get_inat_obs, c(parametros, list(maxresults = 1, meta = TRUE))), error = function(e) NULL)
    total_api <- if (!is.null(metadatos$meta$found)) as.integer(metadatos$meta$found) else NA_integer_
    if (is.na(total_api)) stop("iNaturalist no devolvió el conteo de la consulta; no es posible verificar una descarga completa.")
    if (total_api > 10000L) stop(sprintf("iNaturalist reporta %s registros. El cliente rinat sólo descarga hasta 10000 por consulta; use la exportación oficial de iNaturalist o divida la extracción por periodos antes de combinarla.", format(total_api, big.mark = ",")))
    parametros$maxresults <- total_api
  } else {
    parametros$maxresults <- limite
  }
  # Llamada paginada a la API.
  obs_raw <- tryCatch({
    do.call(rinat::get_inat_obs, parametros)
  }, error = function(e) {
    cat("[iNaturalist] Error durante la llamada a get_inat_obs: ", e$message, "\n")
    return(NULL)
  })
  
  # Dataframe vacío de retorno estandarizado
  df_vacio <- schema_ocurrencias()
  
  if (is.null(obs_raw) || nrow(obs_raw) == 0) {
    cat("[iNaturalist] No se encontraron ocurrencias en la caja delimitadora.\n")
    attr(df_vacio, "api_total") <- if (is.na(total_api)) 0L else total_api
    attr(df_vacio, "api_complete") <- is.null(limite) && !is.na(total_api)
    return(df_vacio)
  }
  
  cat(sprintf("[iNaturalist] Se descargaron %d registros en la caja delimitadora. Aplicando filtro espacial...\n", nrow(obs_raw)))
  
  # 4. Filtro Espacial (Intersección con el polígono exacto del distrito)
  # Convertir el dataframe de iNaturalist a un objeto sf espacial (EPSG:4326)
  obs_sf <- tryCatch({
    sf::st_as_sf(obs_raw, coords = c("longitude", "latitude"), crs = 4326, remove = FALSE)
  }, error = function(e) {
    cat("[iNaturalist] Error al convertir coordenadas a objeto espacial: ", e$message, "\n")
    return(NULL)
  })
  
  if (is.null(obs_sf)) {
    return(df_vacio)
  }
  
  # Intersectar espacialmente con el polígono exacto del distrito
  # Asegurar geometría válida
  poligono_sf <- sf::st_make_valid(poligono_sf)
  obs_sf <- sf::st_make_valid(obs_sf)
  
  interseccion <- sf::st_intersects(obs_sf, poligono_sf, sparse = FALSE)
  
  # Filtrar los registros que están dentro
  obs_dentro <- obs_sf[interseccion[, 1], ]
  
  if (nrow(obs_dentro) == 0) {
    cat("[iNaturalist] Ninguno de los registros se encuentra estrictamente dentro del polígono del distrito.\n")
    return(df_vacio)
  }
  
  # Descartar la columna de geometría para volver a dataframe plano
  datos_raw <- sf::st_drop_geometry(obs_dentro)
  
  # 5. Estandarizar columnas de salida
  datos_procesados <- schema_ocurrencias()[rep(1, nrow(datos_raw)), ]
  
  # Mapeo de columnas
  # iNaturalist a esquema estándar
  datos_procesados$scientificName <- if ("scientific_name" %in% colnames(datos_raw)) datos_raw$scientific_name else as.character(NA)
  datos_procesados$decimalLatitude <- if ("latitude" %in% colnames(datos_raw)) as.numeric(datos_raw$latitude) else as.numeric(NA)
  datos_procesados$decimalLongitude <- if ("longitude" %in% colnames(datos_raw)) as.numeric(datos_raw$longitude) else as.numeric(NA)
  
  # Fecha: puede venir en observed_on o datetime
  if ("observed_on" %in% colnames(datos_raw)) {
    datos_procesados$eventDate <- as.character(datos_raw$observed_on)
  } else if ("datetime" %in% colnames(datos_raw)) {
    datos_procesados$eventDate <- as.character(datos_raw$datetime)
  } else {
    datos_procesados$eventDate <- as.character(NA)
  }
  
  datos_procesados$taxonRank <- if ("rank" %in% colnames(datos_raw)) datos_raw$rank else as.character(NA)
  
  # Rellenar reinos si usamos filtros implícitos
  if (!is.null(grupo)) {
    grupo_clean <- tolower(trimws(grupo))
    datos_procesados$kingdom <- ifelse(grupo_clean == "flora", "Plantae", ifelse(grupo_clean == "fauna", "Animalia", as.character(NA)))
  } else {
    # iNaturalist no devuelve reinos directamente en get_inat_obs, pero podemos inferirlo si se buscó por Plantae/Animalia
    if (!is.null(taxon_query)) {
      if (taxon_query == "Plantae") datos_procesados$kingdom <- "Plantae"
      else if (taxon_query == "Animalia") datos_procesados$kingdom <- "Animalia"
      else datos_procesados$kingdom <- as.character(NA)
    } else {
      datos_procesados$kingdom <- as.character(NA)
    }
  }
  
  # Rellenar campos de taxonomía detallada con NA ya que iNaturalist no los devuelve en este endpoint
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
  
  # Metadatos del origen
  datos_procesados$source <- "iNaturalist"
  datos_procesados$district <- nombre_distrito
  
  cat(sprintf("[iNaturalist] Búsqueda finalizada. %d de %d registros caen dentro del polígono del distrito.\n", 
              nrow(datos_procesados), nrow(obs_raw)))
  attr(datos_procesados, "api_total") <- total_api
  attr(datos_procesados, "api_complete") <- is.null(limite) && !is.na(total_api) && nrow(obs_raw) == total_api
  
  return(datos_procesados)
}
