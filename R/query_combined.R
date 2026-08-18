# query_combined.R
# Función integrada para combinar búsquedas de GBIF e iNaturalist usando polígonos de distritos.

library(dplyr)
library(readr)
library(sf)

source("R/spatial_utils.R")
source("R/query_gbif.R")
source("R/query_inat.R")
source("R/project_utils.R")
source("config/default.R")

#' Realiza una búsqueda combinada de especies en un distrito usando GBIF e iNaturalist
#'
#' @param distrito Nombre del distrito (requerido).
#' @param departamento Nombre del departamento (opcional).
#' @param provincia Nombre de la provincia (opcional).
#' @param nombre_cientifico Nombre de la especie o grupo taxonómico a filtrar (opcional).
#' @param grupo Grupo taxonómico a filtrar: "flora", "fauna" o NULL.
#' @param limite_por_api Número máximo de registros a solicitar por API (def: 500).
#' @param guardar_resultados Lógico; si es TRUE guarda los resultados en data/ (def: TRUE).
#' @param tolerancia_simplificacion Tolerancia en metros para simplificar el polígono en GBIF (def: 100).
#' @return Una lista con el polígono del distrito, el dataframe de ocurrencias y estadísticas de resumen.
buscar_especies_distrito <- function(distrito, 
                                     departamento = NULL, 
                                     provincia = NULL, 
                                     nombre_cientifico = NULL, 
                                     grupo = NULL, 
                                     limite_por_api = configuracion$limite_por_api,
                                     guardar_resultados = TRUE,
                                     tolerancia_simplificacion = configuracion$tolerancia_simplificacion_m) {
  validar_entrada_busqueda(distrito, grupo, limite_por_api)
  crear_directorios_proyecto()
  
  cat("=====================================================================\n")
  cat(sprintf("BÚSQUEDA INTEGRADA EN EL DISTRITO: %s\n", toupper(distrito)))
  if (!is.null(provincia)) cat(sprintf("  Provincia: %s\n", provincia))
  if (!is.null(departamento)) cat(sprintf("  Departamento: %s\n", departamento))
  cat("=====================================================================\n\n")
  
  # 1. Obtener el polígono del distrito
  distrito_sf <- tryCatch({
    obtener_poligono_distrito(distrito = distrito, departamento = departamento, provincia = provincia)
  }, error = function(e) {
    stop(e$message)
  })
  
  nombre_oficial_dist <- distrito_sf$distrito[1]
  nombre_oficial_dep <- distrito_sf$departamento[1]
  
  # 2. Consultar GBIF
  gbif_data <- tryCatch({
    buscar_gbif_por_poligono(
      poligono_sf = distrito_sf,
      nombre_cientifico = nombre_cientifico,
      grupo = grupo,
      limite = limite_por_api,
      tolerancia_simplificacion = tolerancia_simplificacion
    )
  }, error = function(e) {
    if (is.null(limite_por_api)) stop("[GBIF] Descarga completa no realizada: ", e$message)
    cat("[GBIF] Error durante la ejecución del módulo: ", e$message, "\n")
    return(NULL)
  })
  
  # 3. Consultar iNaturalist
  # iNaturalist usa el texto libre 'query' o el específico 'taxon_name'. Mapearemos nombre_cientifico a taxon_name.
  inat_data <- tryCatch({
    buscar_inat_por_poligono(
      poligono_sf = distrito_sf,
      taxon_name = nombre_cientifico,
      grupo = grupo,
      limite = limite_por_api
    )
  }, error = function(e) {
    if (is.null(limite_por_api)) stop("[iNaturalist] Descarga completa no realizada: ", e$message)
    cat("[iNaturalist] Error durante la ejecución del módulo: ", e$message, "\n")
    return(NULL)
  })
  
  # 4. Integrar datos
  # Asegurar que ambos resultados tengan las mismas columnas
  resultados_lista <- list()
  if (!is.null(gbif_data) && nrow(gbif_data) > 0) {
    resultados_lista[[length(resultados_lista) + 1]] <- gbif_data
  }
  if (!is.null(inat_data) && nrow(inat_data) > 0) {
    resultados_lista[[length(resultados_lista) + 1]] <- inat_data
  }
  
  # Si no hay ningún resultado
  if (length(resultados_lista) == 0) {
    cat("\n[RESULTADO] No se encontraron ocurrencias en ninguna de las bases de datos.\n")
    ocurrencias_combinadas <- schema_ocurrencias()
  } else {
    ocurrencias_combinadas <- dplyr::bind_rows(resultados_lista)
    # Sólo elimina duplicados demostrables dentro de una misma fuente; no asume
    # equivalencia entre proveedores sin un identificador cruzado verificable.
    con_id <- dplyr::filter(ocurrencias_combinadas, !is.na(sourceRecordID) & nzchar(sourceRecordID))
    sin_id <- dplyr::filter(ocurrencias_combinadas, is.na(sourceRecordID) | !nzchar(sourceRecordID))
    ocurrencias_combinadas <- dplyr::bind_rows(dplyr::distinct(con_id, source, sourceRecordID, .keep_all = TRUE), sin_id)
    cat(sprintf("\n[RESULTADO] Combinación exitosa. Total de registros: %d\n", nrow(ocurrencias_combinadas)))
  }
  
  # 5. Generar Estadísticas de Resumen
  n_gbif <- ifelse(!is.null(gbif_data), nrow(gbif_data), 0)
  n_inat <- ifelse(!is.null(inat_data), nrow(inat_data), 0)
  
  resumen <- list(
    distrito = nombre_oficial_dist,
    departamento = nombre_oficial_dep,
    total_registros = nrow(ocurrencias_combinadas),
    registros_gbif = n_gbif,
    registros_inat = n_inat,
    limite_por_api = limite_por_api,
    gbif_total_reportado_api = if (!is.null(gbif_data)) attr(gbif_data, "api_total") else NA_integer_,
    inat_total_reportado_api = if (!is.null(inat_data)) attr(inat_data, "api_total") else NA_integer_,
    gbif_descarga_completa_api = if (!is.null(gbif_data)) attr(gbif_data, "api_complete") else FALSE,
    inat_descarga_completa_api = if (!is.null(inat_data)) attr(inat_data, "api_complete") else FALSE,
    nota_cobertura = if (is.null(limite_por_api)) "Se solicitó descarga completa dentro de los límites técnicos de las APIs; los conteos API y el filtrado distrital se registran por separado." else "Se solicitó una muestra limitada por API; la cobertura puede estar truncada."
  )
  
  print(data.frame(
    Origen = c("GBIF", "iNaturalist", "Total"),
    Registros = c(n_gbif, n_inat, nrow(ocurrencias_combinadas))
  ))
  
  # 6. Guardar Resultados en Archivo CSV
  if (guardar_resultados && nrow(ocurrencias_combinadas) > 0) {
    # Nombre único: evita sobrescribir corridas del mismo día.
    distrito_clean <- gsub(" ", "_", tolower(normalizar_texto(nombre_oficial_dist)))
    grupo_clean <- ifelse(is.null(grupo), "biodiversidad", tolower(grupo))
    run_id <- sprintf("%s_p%s_%s_%s", format(Sys.time(), tz = "UTC", "%Y%m%dT%H%M%SZ"), Sys.getpid(), distrito_clean, grupo_clean)
    
    nombre_archivo <- sprintf("data/processed/ocurrencias_%s.csv", run_id)
    nombre_geojson <- NA_character_
    
    tryCatch({
      readr::write_csv(ocurrencias_combinadas, nombre_archivo)
      cat(sprintf("\n[ARCHIVO] Resultados guardados en: '%s'\n", nombre_archivo))
    }, error = function(e) {
      cat("[ARCHIVO] No se pudieron guardar los resultados en CSV: ", e$message, "\n")
    })
    
    # Adicionalmente guardar como GeoJSON para uso en SIG si se desea
    tryCatch({
      # Convertir a sf para guardar
      ocurrencias_geo <- dplyr::filter(ocurrencias_combinadas, is.finite(decimalLongitude), is.finite(decimalLatitude))
      sf_guardar <- sf::st_as_sf(
        ocurrencias_geo,
        coords = c("decimalLongitude", "decimalLatitude"), 
        crs = 4326, 
        remove = FALSE
      )
      nombre_geojson <- sprintf("data/processed/ocurrencias_%s.geojson", run_id)
      sf::st_write(sf_guardar, nombre_geojson, quiet = TRUE)
      cat(sprintf("[ARCHIVO] Capa espacial guardada en GeoJSON: '%s'\n", nombre_geojson))
    }, error = function(e) {
      # No bloquear si falla el GeoJSON (puede deberse a coordenadas faltantes o nulas)
      cat("[SIG] Nota: No se pudo exportar a GeoJSON (compruebe si hay filas con coordenadas nulas).\n")
    })
    nombre_manifiesto <- sprintf("data/processed/manifiesto_%s.json", run_id)
    escribir_manifiesto(run_id,
      list(distrito = distrito, departamento = departamento, provincia = provincia,
        nombre_cientifico = nombre_cientifico, grupo = grupo, limite_por_api = limite_por_api,
        tolerancia_simplificacion_m = tolerancia_simplificacion),
      distrito_sf, resumen, list(csv = nombre_archivo, geojson = nombre_geojson), nombre_manifiesto)
    cat(sprintf("[ARCHIVO] Manifiesto de reproducibilidad guardado en: '%s'\n", nombre_manifiesto))
  }
  
  return(list(
    distrito_sf = distrito_sf,
    ocurrencias = ocurrencias_combinadas,
    resumen = resumen,
    parametros = list(distrito = distrito, departamento = departamento, provincia = provincia,
      nombre_cientifico = nombre_cientifico, grupo = grupo, limite_por_api = limite_por_api,
      tolerancia_simplificacion_m = tolerancia_simplificacion)
  ))
}
