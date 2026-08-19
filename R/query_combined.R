# query_combined.R
# Funciones integradas para consolidar busquedas de GBIF e iNaturalist usando poligonos de distritos y provincias.

#' Realiza una busqueda combinada de especies en una unidad administrativa del Peru
#'
#' @param nombre Nombre de la unidad administrativa (distrito o provincia).
#' @param nivel Nivel administrativo: "distrito" o "provincia" (def: "distrito").
#' @param departamento Nombre del departamento (opcional).
#' @param provincia Nombre de la provincia (opcional, aplicable cuando nivel = "distrito").
#' @param nombre_cientifico Nombre de la especie o grupo taxonomico a filtrar (opcional).
#' @param grupo Grupo taxonomico a filtrar: "flora", "fauna" o NULL.
#' @param limite_por_api Numero maximo de registros a solicitar por API (def: 500).
#' @param guardar_resultados Logico; si es TRUE guarda los resultados en processed/ (def: FALSE).
#' @param tolerancia_simplificacion Tolerancia en metros para simplificar el poligono en GBIF (def: 100).
#' @return Una lista con el poligono de la unidad, el dataframe de ocurrencias consolidado y estadisticas de resumen.
#' @export
buscar_especies_peru <- function(nombre,
                                 nivel = c("distrito", "provincia"),
                                 departamento = NULL,
                                 provincia = NULL,
                                 nombre_cientifico = NULL,
                                 grupo = NULL,
                                 limite_por_api = configuracion_predeterminada()$limite_por_api,
                                 guardar_resultados = FALSE,
                                 tolerancia_simplificacion = configuracion_predeterminada()$tolerancia_simplificacion_m) {
  nivel <- match.arg(nivel)
  validar_entrada_busqueda(unidad = nombre, grupo = grupo, limite = limite_por_api, nivel = nivel)
  
  cat("=====================================================================\n")
  cat(sprintf("BUSQUEDA INTEGRADA EN %s: %s\n", toupper(nivel), toupper(nombre)))
  if (!is.null(provincia) && nivel == "distrito") cat(sprintf("  Provincia: %s\n", provincia))
  if (!is.null(departamento)) cat(sprintf("  Departamento: %s\n", departamento))
  cat("=====================================================================\n\n")
  
  # 1. Obtener el poligono de la unidad administrativa
  unidad_sf <- tryCatch({
    obtener_poligono_unidad(nombre = nombre, nivel = nivel, departamento = departamento, provincia = provincia)
  }, error = function(e) {
    stop(e$message)
  })
  
  nombre_oficial_dist <- if (!is.null(unidad_sf$distrito) && !is.na(unidad_sf$distrito[1])) unidad_sf$distrito[1] else NA_character_
  nombre_oficial_prov <- if (!is.null(unidad_sf$provincia) && !is.na(unidad_sf$provincia[1])) unidad_sf$provincia[1] else NA_character_
  nombre_oficial_dep <- if (!is.null(unidad_sf$departamento) && !is.na(unidad_sf$departamento[1])) unidad_sf$departamento[1] else NA_character_
  etiqueta_unidad <- if (!is.na(nombre_oficial_dist)) nombre_oficial_dist else nombre_oficial_prov
  
  # 2. Consultar GBIF
  gbif_data <- tryCatch({
    buscar_gbif_por_poligono(
      poligono_sf = unidad_sf,
      nombre_cientifico = nombre_cientifico,
      grupo = grupo,
      limite = limite_por_api,
      tolerancia_simplificacion = tolerancia_simplificacion
    )
  }, error = function(e) {
    if (is.null(limite_por_api)) stop("[GBIF] Descarga completa no realizada: ", e$message)
    cat("[GBIF] Error durante la ejecucion del modulo: ", e$message, "\n")
    return(NULL)
  })
  
  # 3. Consultar iNaturalist
  inat_data <- tryCatch({
    buscar_inat_por_poligono(
      poligono_sf = unidad_sf,
      taxon_name = nombre_cientifico,
      grupo = grupo,
      limite = limite_por_api
    )
  }, error = function(e) {
    if (is.null(limite_por_api)) stop("[iNaturalist] Descarga completa no realizada: ", e$message)
    cat("[iNaturalist] Error durante la ejecucion del modulo: ", e$message, "\n")
    return(NULL)
  })
  
  # 4. Integrar y estandarizar datos
  resultados_lista <- list()
  if (!is.null(gbif_data) && nrow(gbif_data) > 0) {
    resultados_lista[[length(resultados_lista) + 1]] <- gbif_data
  }
  if (!is.null(inat_data) && nrow(inat_data) > 0) {
    resultados_lista[[length(resultados_lista) + 1]] <- inat_data
  }
  
  if (length(resultados_lista) == 0) {
    cat("\n[RESULTADO] No se encontraron ocurrencias en ninguna de las bases de datos.\n")
    ocurrencias_combinadas <- schema_ocurrencias()
  } else {
    ocurrencias_combinadas <- dplyr::bind_rows(resultados_lista)
    # Deduplicacion dentro de la misma fuente
    con_id <- dplyr::filter(ocurrencias_combinadas, !is.na(sourceRecordID) & nzchar(sourceRecordID))
    sin_id <- dplyr::filter(ocurrencias_combinadas, is.na(sourceRecordID) | !nzchar(sourceRecordID))
    ocurrencias_combinadas <- dplyr::bind_rows(dplyr::distinct(con_id, source, sourceRecordID, .keep_all = TRUE), sin_id)
    cat(sprintf("\n[RESULTADO] Consolidacion exitosa. Total de registros unificados: %d\n", nrow(ocurrencias_combinadas)))
  }
  
  # 5. Generar Estadisticas de Resumen
  n_gbif <- ifelse(!is.null(gbif_data), nrow(gbif_data), 0)
  n_inat <- ifelse(!is.null(inat_data), nrow(inat_data), 0)
  
  resumen <- list(
    nivel = nivel,
    unidad = etiqueta_unidad,
    distrito = nombre_oficial_dist,
    provincia = nombre_oficial_prov,
    departamento = nombre_oficial_dep,
    total_registros = nrow(ocurrencias_combinadas),
    registros_gbif = n_gbif,
    registros_inat = n_inat,
    limite_por_api = limite_por_api,
    gbif_total_reportado_api = if (!is.null(gbif_data)) attr(gbif_data, "api_total") else NA_integer_,
    inat_total_reportado_api = if (!is.null(inat_data)) attr(inat_data, "api_total") else NA_integer_,
    gbif_descarga_completa_api = if (!is.null(gbif_data)) attr(gbif_data, "api_complete") else FALSE,
    inat_descarga_completa_api = if (!is.null(inat_data)) attr(inat_data, "api_complete") else FALSE,
    nota_cobertura = if (is.null(limite_por_api)) "Se solicito descarga completa dentro de los limites tecnicos de las APIs." else "Se solicito una muestra limitada por API; la cobertura puede estar truncada."
  )
  
  print(data.frame(
    Origen = c("GBIF", "iNaturalist", "Total"),
    Registros = c(n_gbif, n_inat, nrow(ocurrencias_combinadas))
  ))
  
  resultado_obj <- list(
    unidad_sf = unidad_sf,
    distrito_sf = unidad_sf, # Alias para compatibilidad
    ocurrencias = ocurrencias_combinadas,
    resumen = resumen,
    parametros = list(
      nombre = nombre,
      nivel = nivel,
      departamento = departamento,
      provincia = provincia,
      nombre_cientifico = nombre_cientifico,
      grupo = grupo,
      limite_por_api = limite_por_api,
      tolerancia_simplificacion_m = tolerancia_simplificacion
    )
  )
  
  # 6. Guardar Resultados en Archivos si se solicita explicitamente
  if (isTRUE(guardar_resultados) && nrow(ocurrencias_combinadas) > 0) {
    exportar_resultados(resultado_obj)
  }
  
  return(resultado_obj)
}

#' Realiza una busqueda combinada de especies en un distrito usando GBIF e iNaturalist
#'
#' @param distrito Nombre del distrito (requerido).
#' @param departamento Nombre del departamento (opcional).
#' @param provincia Nombre de la provincia (opcional).
#' @param nombre_cientifico Nombre de la especie o grupo taxonomico a filtrar (opcional).
#' @param grupo Grupo taxonomico a filtrar: "flora", "fauna" o NULL.
#' @param limite_por_api Numero maximo de registros a solicitar por API (def: 500).
#' @param guardar_resultados Logico; si es TRUE guarda los resultados en processed/ (def: FALSE).
#' @param tolerancia_simplificacion Tolerancia en metros para simplificar el poligono en GBIF (def: 100).
#' @return Una lista con el poligono del distrito, el dataframe de ocurrencias y estadisticas de resumen.
#' @export
buscar_especies_distrito <- function(distrito, 
                                     departamento = NULL, 
                                     provincia = NULL, 
                                     nombre_cientifico = NULL, 
                                     grupo = NULL, 
                                     limite_por_api = configuracion_predeterminada()$limite_por_api,
                                     guardar_resultados = FALSE,
                                     tolerancia_simplificacion = configuracion_predeterminada()$tolerancia_simplificacion_m) {
  buscar_especies_peru(
    nombre = distrito,
    nivel = "distrito",
    departamento = departamento,
    provincia = provincia,
    nombre_cientifico = nombre_cientifico,
    grupo = grupo,
    limite_por_api = limite_por_api,
    guardar_resultados = guardar_resultados,
    tolerancia_simplificacion = tolerancia_simplificacion
  )
}

#' Realiza una busqueda combinada de especies en una provincia usando GBIF e iNaturalist
#'
#' @param provincia Nombre de la provincia (requerido).
#' @param departamento Nombre del departamento (opcional).
#' @param nombre_cientifico Nombre de la especie o grupo taxonomico a filtrar (opcional).
#' @param grupo Grupo taxonomico a filtrar: "flora", "fauna" o NULL.
#' @param limite_por_api Numero maximo de registros a solicitar por API (def: 500).
#' @param guardar_resultados Logico; si es TRUE guarda los resultados en processed/ (def: FALSE).
#' @param tolerancia_simplificacion Tolerancia en metros para simplificar el poligono en GBIF (def: 100).
#' @return Una lista con el poligono de la provincia, el dataframe de ocurrencias consolidado y estadisticas de resumen.
#' @export
buscar_especies_provincia <- function(provincia, 
                                      departamento = NULL, 
                                      nombre_cientifico = NULL, 
                                      grupo = NULL, 
                                      limite_por_api = configuracion_predeterminada()$limite_por_api,
                                      guardar_resultados = FALSE,
                                      tolerancia_simplificacion = configuracion_predeterminada()$tolerancia_simplificacion_m) {
  buscar_especies_peru(
    nombre = provincia,
    nivel = "provincia",
    departamento = departamento,
    provincia = NULL,
    nombre_cientifico = nombre_cientifico,
    grupo = grupo,
    limite_por_api = limite_por_api,
    guardar_resultados = guardar_resultados,
    tolerancia_simplificacion = tolerancia_simplificacion
  )
}
