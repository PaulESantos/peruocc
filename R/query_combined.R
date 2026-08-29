# query_combined.R
# Funciones integradas para consolidar busquedas de GBIF e iNaturalist usando poligonos de distritos y provincias.

nombre_seguro_cache <- function(texto) {
  texto <- normalizar_texto(paste(texto, collapse = "_"))
  texto <- gsub(" +", "_", tolower(texto))
  substr(texto, 1, 120)
}

consolidar_ocurrencias <- function(resultados_lista) {
  resultados_lista <- Filter(function(x) !is.null(x) && nrow(x) > 0, resultados_lista)
  if (length(resultados_lista) == 0) return(schema_ocurrencias())
  ocurrencias <- dplyr::bind_rows(resultados_lista)
  con_id <- dplyr::filter(ocurrencias, !is.na(sourceRecordID) & nzchar(sourceRecordID))
  sin_id <- dplyr::filter(ocurrencias, is.na(sourceRecordID) | !nzchar(sourceRecordID))
  res <- dplyr::bind_rows(dplyr::distinct(con_id, source, sourceRecordID, .keep_all = TRUE), sin_id)
  as_peruocc_tbl(res)
}

consultar_lotes_espaciales <- function(lotes_sf, nombre_cientifico, grupo, limite,
                                       tolerancia_simplificacion, cache_dir, reintentos,
                                       pausa_entre_lotes_s, clave_ejecucion) {
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  resultados <- list()
  fallos <- character()
  total_lotes <- nrow(lotes_sf)
  es_multi_lote <- (total_lotes > 1L)
  
  if (es_multi_lote) {
    nombres_distritos <- if ("distrito" %in% names(lotes_sf)) unique(stats::na.omit(lotes_sf$distrito)) else character()
    if (length(nombres_distritos) > 0) {
      cli::cli_alert_info("Procesando {total_lotes} lotes espaciales (distritos): {.val {nombres_distritos}}")
    } else {
      cli::cli_alert_info("Procesando {total_lotes} lotes espaciales...")
    }
  }

  for (i in seq_len(total_lotes)) {
    lote <- lotes_sf[i, ]
    nombre_lote <- if ("distrito" %in% names(lote) && !is.na(lote$distrito[1])) {
      lote$distrito[1]
    } else if ("provincia" %in% names(lote) && !is.na(lote$provincia[1])) {
      lote$provincia[1]
    } else if ("tile_id" %in% names(lote)) {
      paste0("Bloque ", lote$tile_id[1])
    } else {
      paste0("Lote ", i)
    }
    
    n_gbif <- 0L
    n_inat <- 0L
    checkpoint_gbif <- FALSE
    checkpoint_inat <- FALSE
    
    for (fuente in c("gbif", "inat")) {
      archivo_cache <- file.path(cache_dir, sprintf("%s_lote_%05d_%s.rds", clave_ejecucion, i, fuente))
      resultado <- NULL
      if (file.exists(archivo_cache)) {
        resultado <- tryCatch(readRDS(archivo_cache), error = function(e) NULL)
        if (!is.null(resultado)) {
          if (fuente == "gbif") checkpoint_gbif <- TRUE else checkpoint_inat <- TRUE
        }
      }
      if (is.null(resultado)) {
        resultado <- tryCatch({
          if (fuente == "gbif") {
            buscar_gbif_por_poligono(lote, nombre_cientifico, grupo, limite,
                                     tolerancia_simplificacion, reintentos,
                                     verbose = !es_multi_lote)
          } else {
            buscar_inat_por_poligono(lote, taxon_name = nombre_cientifico, grupo = grupo,
                                     limite = limite, reintentos = reintentos,
                                     verbose = !es_multi_lote)
          }
        }, error = function(e) {
          fallos <<- c(fallos, sprintf("lote %d %s: %s", i, fuente, e$message))
          NULL
        })
        if (!is.null(resultado)) saveRDS(resultado, archivo_cache)
      }
      if (!is.null(resultado)) {
        resultados[[length(resultados) + 1L]] <- resultado
        if (fuente == "gbif") n_gbif <- nrow(resultado) else n_inat <- nrow(resultado)
      }
    }
    
    if (es_multi_lote) {
      if (checkpoint_gbif && checkpoint_inat) {
        cli::cli_alert_info("Lote {i}/{total_lotes} [{toupper(nombre_lote)}]: recuperado de checkpoint ({n_gbif + n_inat} registros).")
      } else {
        cli::cli_alert_success("Lote {i}/{total_lotes} [{toupper(nombre_lote)}]: {n_gbif} (GBIF) + {n_inat} (iNat) = {n_gbif + n_inat} registros.")
      }
    }
    
    if (i < total_lotes && pausa_entre_lotes_s > 0) Sys.sleep(pausa_entre_lotes_s)
  }
  list(ocurrencias = consolidar_ocurrencias(resultados), fallos = fallos)
}

preparar_lotes_espaciales <- function(unidad_sf, nivel, nombre, departamento,
                                      estrategia_espacial,
                                      max_area_ha = configuracion_predeterminada()$max_area_ha_por_lote,
                                      max_lotes = configuracion_predeterminada()$max_lotes_espaciales,
                                      nombre_cientifico = NULL,
                                      grupo = NULL) {
  if (estrategia_espacial == "directa") {
    unidad_sf$tile_id <- 1L
    return(unidad_sf)
  }
  bases <- if (nivel == "provincia") {
    obtener_distritos_provincia(nombre, departamento)
  } else {
    unidad_sf
  }
  if (estrategia_espacial == "segmentada") {
    lotes <- lapply(seq_len(nrow(bases)), function(i) {
      dividir_poligono_por_area(bases[i, ], max_area_ha = max_area_ha, max_lotes = max_lotes)
    })
    res <- do.call(rbind, lotes)
    res$tile_id <- seq_len(nrow(res))
    return(res)
  }
  
  # En modo "auto":
  # 1. Si es búsqueda de una especie concreta, se consulta en 1 bloque directo por unidad
  # 2. Si es inventario general y la unidad es grande (> 50,000 ha),
  #    se divide adaptativamente en macro-bloques controlados (máximo max_lotes).
  if (is.null(nombre_cientifico)) {
    umbral_macro_ha <- configuracion_predeterminada()$umbral_macro_bloques_ha
    lotes_lista <- list()
    for (i in seq_len(nrow(bases))) {
      b_i <- bases[i, ]
      area_ha <- tryCatch({
        as.numeric(sf::st_area(sf::st_union(sf::st_transform(b_i, 3857)))) / 10000
      }, error = function(e) 0)
      
      if (area_ha > umbral_macro_ha) {
        lotes_lista[[i]] <- dividir_poligono_por_area(b_i, max_area_ha = umbral_macro_ha, max_lotes = max_lotes)
      } else {
        b_i$tile_id <- 1L
        lotes_lista[[i]] <- b_i
      }
    }
    res <- do.call(rbind, lotes_lista)
    res$tile_id <- seq_len(nrow(res))
    return(res)
  }
  
  bases$tile_id <- seq_len(nrow(bases))
  bases
}

#' Busca y consolida ocurrencias en una unidad administrativa del Perú
#'
#' Es la función general de consulta. Obtiene el límite oficial, consulta GBIF e
#' iNaturalist, valida localmente que cada coordenada esté dentro del polígono y
#' unifica las columnas en un esquema común. Para áreas extensas puede dividir
#' la consulta en lotes con checkpoint, evitando que un fallo obligue a empezar
#' de nuevo.
#'
#' @param nombre Cadena no vacía con el distrito o provincia solicitado, según
#'   `nivel`. La coincidencia ignora tildes y mayúsculas.
#' @param nivel Uno de `"distrito"` o `"provincia"`; determina cómo se interpreta
#'   `nombre`. Las provincias se resuelven con sus distritos componentes cuando
#'   se usa la estrategia segmentada.
#' @param departamento `NULL` o cadena con el departamento. Es muy recomendable
#'   para resolver nombres repetidos y reduce la descarga de límites.
#' @param provincia `NULL` o cadena con la provincia. Solo aplica a búsquedas
#'   distritales y ayuda a desambiguar homónimos.
#' @param nombre_cientifico `NULL` o cadena con un taxón, por ejemplo
#'   `"Panthera onca"`. GBIF intenta resolverlo en su backbone taxonómico;
#'   iNaturalist lo usa como filtro por nombre.
#' @param grupo `NULL`, `"flora"` o `"fauna"` (sin distinguir mayúsculas). Se
#'   traduce a Plantae o Animalia. Puede combinarse con `nombre_cientifico`.
#' @param limite_por_api Entero entre 1 y 10000, o `NULL`. Es el máximo por
#'   fuente y lote, no el máximo final consolidado. `NULL` solicita descarga
#'   completa solo cuando cada API informa un conteo dentro de su capacidad;
#'   puede ser lento y detenerse para consultas demasiado grandes.
#' @param guardar_resultados Lógico. Si es `TRUE`, ejecuta
#'   [exportar_resultados()] al final. No sobrescribe resultados previos porque
#'   genera un identificador temporal nuevo.
#' @param tolerancia_simplificacion Distancia en metros para simplificar WKT en
#'   GBIF si supera el límite de longitud de la API.
#' @param estrategia_espacial Estrategia de particionamiento (`"auto"`, `"directa"`
#'   o `"segmentada"`). Con `"auto"`, las provincias se particionan por sus
#'   distritos y los distritos extensos se dividen en macro-bloques adaptativos.
#' @param max_area_ha Límite de área en hectáreas por lote para teselación
#'   cuando se usa `estrategia_espacial = "segmentada"`.
#' @param max_lotes Número máximo de macro-bloques espaciales generados por
#'   unidad geográfica para evitar saturar las cuotas de las APIs.
#' @param cache_dir Directorio para guardar checkpoints `.rds` por lote y fuente.
#' @param reintentos Entero positivo con el número de intentos para llamadas API.
#' @param pausa_entre_lotes_s Pausa en segundos entre lotes consecutivos.
#' @return Objeto con clase `peruocc_resultado` (lista con límite `unidad_sf`,
#'   tibble de `ocurrencias`, `resumen` estadístico y `parametros`).
#' @details La deduplicación usa `source` y `sourceRecordID`; un mismo registro
#' procedente de GBIF e iNaturalist se mantiene, porque son fuentes distintas.
#' Los checkpoints se escriben tras terminar cada fuente/lote. Revise
#' `resultado$resumen$fallos_lotes` antes de interpretar una descarga como
#' completa.
#' @examples
#' \dontrun{
#' resultado <- buscar_especies_peru(
#'   nombre = "Tambopata", nivel = "provincia", departamento = "Madre de Dios",
#'   grupo = "fauna", limite_por_api = 1000, max_area_ha = 1000
#' )
#' head(resultado$ocurrencias)
#' }
#' @export
buscar_especies_peru <- function(nombre,
                                 nivel = c("distrito", "provincia"),
                                 departamento = NULL,
                                 provincia = NULL,
                                 nombre_cientifico = NULL,
                                 grupo = NULL,
                                 limite_por_api = configuracion_predeterminada()$limite_por_api,
                                 guardar_resultados = FALSE,
                                 tolerancia_simplificacion = configuracion_predeterminada()$tolerancia_simplificacion_m,
                                 estrategia_espacial = c("auto", "directa", "segmentada"),
                                 max_area_ha = configuracion_predeterminada()$max_area_ha_por_lote,
                                 max_lotes = configuracion_predeterminada()$max_lotes_espaciales,
                                 cache_dir = ruta_cache("consultas_ocurrencias"),
                                 reintentos = configuracion_predeterminada()$reintentos_api,
                                 pausa_entre_lotes_s = configuracion_predeterminada()$pausa_entre_lotes_s) {
  nivel <- match.arg(nivel)
  estrategia_espacial <- match.arg(estrategia_espacial)
  validar_entrada_busqueda(unidad = nombre, grupo = grupo, limite = limite_por_api, nivel = nivel)
  
  cli::cli_h1("B\u00fasqueda Integrada: {toupper(nombre)} ({toupper(nivel)})")
  params_items <- character()
  if (!is.null(departamento)) params_items <- c(params_items, paste0("Departamento: ", departamento))
  if (!is.null(provincia) && nivel == "distrito") params_items <- c(params_items, paste0("Provincia: ", provincia))
  if (!is.null(nombre_cientifico)) params_items <- c(params_items, paste0("Tax\u00f3n: ", nombre_cientifico))
  if (!is.null(grupo)) params_items <- c(params_items, paste0("Grupo: ", grupo))
  if (length(params_items) > 0) {
    cli::cli_ul(params_items)
  }
  
  # 1. Obtener el poligono de la unidad administrativa
  unidad_sf <- tryCatch({
    obtener_poligono_unidad(nombre = nombre, nivel = nivel, departamento = departamento, provincia = provincia)
  }, error = function(e) {
    cli::cli_abort(e$message, parent = e)
  })
  
  nombre_oficial_dist <- if (!is.null(unidad_sf$distrito) && !is.na(unidad_sf$distrito[1])) unidad_sf$distrito[1] else NA_character_
  nombre_oficial_prov <- if (!is.null(unidad_sf$provincia) && !is.na(unidad_sf$provincia[1])) unidad_sf$provincia[1] else NA_character_
  nombre_oficial_dep <- if (!is.null(unidad_sf$departamento) && !is.na(unidad_sf$departamento[1])) unidad_sf$departamento[1] else NA_character_
  etiqueta_unidad <- if (!is.na(nombre_oficial_dist)) nombre_oficial_dist else nombre_oficial_prov
  
  # 2. Provincias se descomponen en distritos; unidades extensas se teselan de forma adaptativa.
  lotes_sf <- preparar_lotes_espaciales(unidad_sf, nivel, nombre, departamento,
                                        estrategia_espacial, max_area_ha, max_lotes,
                                        nombre_cientifico, grupo)
  clave_ejecucion <- nombre_seguro_cache(c(nivel, nombre, departamento, nombre_cientifico, grupo,
                                           limite_por_api, max_area_ha, max_lotes, tolerancia_simplificacion,
                                           estrategia_espacial))
  descarga <- consultar_lotes_espaciales(lotes_sf, nombre_cientifico, grupo, limite_por_api,
                                         tolerancia_simplificacion, cache_dir, reintentos,
                                         pausa_entre_lotes_s, clave_ejecucion)
  ocurrencias_combinadas <- descarga$ocurrencias
  if (nrow(ocurrencias_combinadas) == 0) {
    cli::cli_alert_warning("No se encontraron ocurrencias en ninguna de las bases de datos.")
  } else {
    cli::cli_alert_success("Consolidaci\u00f3n exitosa. Total de registros unificados: {.strong {nrow(ocurrencias_combinadas)}}")
  }
  
  # 5. Generar Estadisticas de Resumen
  n_gbif <- sum(ocurrencias_combinadas$source == "GBIF")
  n_inat <- sum(ocurrencias_combinadas$source == "iNaturalist")
  
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
    gbif_total_reportado_api = NA_integer_,
    inat_total_reportado_api = NA_integer_,
    gbif_descarga_completa_api = FALSE,
    inat_descarga_completa_api = FALSE,
    lotes_espaciales = nrow(lotes_sf),
    fallos_lotes = descarga$fallos,
    nota_cobertura = if (is.null(limite_por_api)) "Se solicito descarga completa dentro de los limites tecnicos de las APIs." else "Se solicito una muestra limitada por API; la cobertura puede estar truncada."
  )
  
  cli::cli_h2("Resumen de Registros")
  cli::cli_bullets(c(
    "*" = "GBIF: {.val {n_gbif}} registro(s)",
    "*" = "iNaturalist: {.val {n_inat}} registro(s)",
    "v" = "Total consolidado: {.strong {nrow(ocurrencias_combinadas)}} registro(s)"
  ))
  if (length(descarga$fallos) > 0) {
    cli::cli_alert_danger("Se registraron fallos en {length(descarga$fallos)} lote(s):")
    cli::cli_ul(descarga$fallos)
  }
  
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
      tolerancia_simplificacion_m = tolerancia_simplificacion,
      estrategia_espacial = estrategia_espacial,
      max_area_ha = max_area_ha,
      cache_dir = cache_dir
    )
  )
  
  # 6. Guardar Resultados en Archivos si se solicita explicitamente
  if (isTRUE(guardar_resultados) && nrow(ocurrencias_combinadas) > 0) {
    exportar_resultados(resultado_obj)
  }
  
  return(resultado_obj)
}

#' Busca ocurrencias en un distrito peruano
#'
#' Atajo legible de [buscar_especies_peru()] con `nivel = "distrito"`. Acepte
#' los mismos filtros y devuelve la misma estructura de resultado.
#'
#' @param distrito Cadena no vacía con el nombre del distrito.
#' @param departamento `NULL` o departamento que contiene al distrito.
#' @param provincia `NULL` o provincia que contiene al distrito; úselo junto a
#'   `departamento` para resolver nombres repetidos.
#' @param nombre_cientifico `NULL` o nombre de taxón para filtrar resultados.
#' @param grupo `NULL`, `"flora"` o `"fauna"`.
#' @param limite_por_api Entero entre 1 y 10000, o `NULL`; consulte
#'   [buscar_especies_peru()] para sus límites y consecuencias.
#' @param guardar_resultados Lógico que exporta CSV, GeoJSON y manifiesto al
#'   finalizar cuando es `TRUE`.
#' @param tolerancia_simplificacion Tolerancia de simplificación para la llamada
#'   a GBIF, expresada en metros.
#' @param ... Controles avanzados reenviados a [buscar_especies_peru()]:
#'   `estrategia_espacial`, `max_area_ha`, `cache_dir`, `reintentos` y
#'   `pausa_entre_lotes_s`.
#' @return Lista con límite, ocurrencias, resumen y parámetros. Consulte el
#'   valor retornado por [buscar_especies_peru()].
#' @examples
#' \dontrun{
#' res <- buscar_especies_distrito("Miraflores", departamento = "Lima", grupo = "flora")
#' head(res$ocurrencias)
#' }
#' @export
buscar_especies_distrito <- function(distrito, 
                                     departamento = NULL, 
                                     provincia = NULL, 
                                     nombre_cientifico = NULL, 
                                     grupo = NULL, 
                                     limite_por_api = configuracion_predeterminada()$limite_por_api,
                                     guardar_resultados = FALSE,
                                     tolerancia_simplificacion = configuracion_predeterminada()$tolerancia_simplificacion_m,
                                     ...) {
  buscar_especies_peru(
    nombre = distrito,
    nivel = "distrito",
    departamento = departamento,
    provincia = provincia,
    nombre_cientifico = nombre_cientifico,
    grupo = grupo,
    limite_por_api = limite_por_api,
    guardar_resultados = guardar_resultados,
    tolerancia_simplificacion = tolerancia_simplificacion,
    ...
  )
}

#' Busca ocurrencias en una provincia peruana
#'
#' Atajo de [buscar_especies_peru()] con `nivel = "provincia"`. Con la
#' estrategia predeterminada procesa los distritos de forma independiente y
#' consolida al final, una opción más recuperable que consultar la provincia
#' disuelta en una sola petición.
#'
#' @param provincia Cadena no vacía con el nombre de la provincia.
#' @param departamento `NULL` o el departamento que contiene la provincia. Es
#'   necesario cuando el nombre es ambiguo.
#' @param nombre_cientifico `NULL` o nombre de taxón para filtrar.
#' @param grupo `NULL`, `"flora"` o `"fauna"`.
#' @param limite_por_api Entero entre 1 y 10000, o `NULL`; se aplica a cada
#'   fuente y lote.
#' @param guardar_resultados Lógico; si es `TRUE` exporta los resultados finales.
#' @param tolerancia_simplificacion Tolerancia para simplificación de WKT de
#'   GBIF, medida en metros.
#' @param ... Controles avanzados reenviados a [buscar_especies_peru()].
#'   Destacan `max_area_ha` para ajustar las teselas y `cache_dir` para reanudar.
#' @return Lista con límite provincial disuelto, ocurrencias consolidadas,
#'   resumen de lotes y parámetros de la ejecución.
#' @examples
#' \dontrun{
#' res <- buscar_especies_provincia("Urubamba", departamento = "Cusco", grupo = "fauna")
#' head(res$ocurrencias)
#' }
#' @export
buscar_especies_provincia <- function(provincia, 
                                      departamento = NULL, 
                                      nombre_cientifico = NULL, 
                                      grupo = NULL, 
                                      limite_por_api = configuracion_predeterminada()$limite_por_api,
                                      guardar_resultados = FALSE,
                                      tolerancia_simplificacion = configuracion_predeterminada()$tolerancia_simplificacion_m,
                                      ...) {
  buscar_especies_peru(
    nombre = provincia,
    nivel = "provincia",
    departamento = departamento,
    provincia = NULL,
    nombre_cientifico = nombre_cientifico,
    grupo = grupo,
    limite_por_api = limite_por_api,
    guardar_resultados = guardar_resultados,
    tolerancia_simplificacion = tolerancia_simplificacion,
    ...
  )
}

#' Busca ocurrencias en un polígono personalizado
#'
#' Consulta GBIF e iNaturalist sobre un límite aportado por el usuario. El área
#' se normaliza mediante [preparar_poligono_usuario()], se consulta por WKT o
#' caja delimitadora y, finalmente, los puntos se recortan contra la geometría
#' exacta localmente. Soporta áreas de estudio, buffers, ANP y polígonos de
#' múltiples partes.
#'
#' @param poligono Objeto `sf`, `sfc` o `Spatial`, o ruta de longitud uno a un
#'   archivo `.shp`, `.geojson`, `.gpkg` o `.kml`. Debe tener geometría
#'   poligonal; los elementos múltiples se disuelven en un único límite.
#' @param nombre `NULL` o etiqueta de texto para identificar la consulta. Si es
#'   `NULL`, se usa el nombre del archivo o `"Poligono_Personalizado"`.
#' @param nombre_cientifico `NULL` o nombre de especie/grupo taxonómico. Se usa
#'   para filtrar ambas fuentes, aunque cada API puede resolver sinónimos de
#'   forma distinta.
#' @param grupo `NULL`, `"flora"` o `"fauna"`; filtra por Plantae o Animalia.
#' @param limite_por_api Entero entre 1 y 10000, o `NULL`. Es un máximo por API
#'   y tesela; no es el máximo global. `NULL` intenta recuperar todas las filas
#'   solamente si los límites técnicos de ambas APIs lo permiten.
#' @param guardar_resultados Lógico. Con `TRUE` exporta los resultados en la
#'   carpeta `processed/` configurada con [peruocc_data_dir()].
#' @param tolerancia_simplificacion Número no negativo, en metros, usado para
#'   acortar la geometría WKT de GBIF. El filtro espacial final usa siempre la
#'   geometría original.
#' @param estrategia_espacial Una de `"auto"`, `"segmentada"` o `"directa"`.
#'   `"auto"` equivale a `"segmentada"` y divide polígonos grandes;
#'   `"directa"` evita teselas y solo es aconsejable para áreas pequeñas.
#' @param max_area_ha Área positiva, en hectáreas, objetivo de cada tesela para
#'   estrategia segmentada. El valor 1000 equilibra tamaño de petición y número
#'   de llamadas; reduzca este valor ante errores por volumen.
#' @param max_lotes Número máximo de macro-bloques espaciales generados por
#'   unidad geográfica para evitar saturar las cuotas de las APIs.
#' @param cache_dir Directorio escribible para checkpoints de resultados por
#'   fuente/lote. Conservarlo permite reanudar una extracción interrumpida.
#' @param reintentos Entero positivo con el número máximo de reintentos de
#'   llamadas remotas transitorias.
#' @param pausa_entre_lotes_s Número no negativo de segundos de espera entre
#'   lotes. Aumentarlo es útil ante respuestas de límite de tasa.
#' @return Lista con `unidad_sf`, `ocurrencias`, `resumen` y `parametros`.
#'   `resumen$fallos_lotes` indica si alguna fuente/lote no pudo completarse.
#' @examples
#' coords <- matrix(c(-77.05, -12.10, -77.01, -12.10, -77.01, -12.05,
#'                    -77.05, -12.05, -77.05, -12.10), ncol = 2, byrow = TRUE)
#' zona <- sf::st_as_sf(sf::st_sfc(sf::st_polygon(list(coords)), crs = 4326))
#' \dontrun{
#' resultado <- buscar_especies_poligono(zona, nombre = "Zona de prueba",
#'                                        grupo = "flora", limite_por_api = 500)
#' }
#' @export
buscar_especies_poligono <- function(poligono,
                                     nombre = NULL,
                                     nombre_cientifico = NULL,
                                     grupo = NULL,
                                     limite_por_api = configuracion_predeterminada()$limite_por_api,
                                     guardar_resultados = FALSE,
                                     tolerancia_simplificacion = configuracion_predeterminada()$tolerancia_simplificacion_m,
                                     estrategia_espacial = c("auto", "directa", "segmentada"),
                                     max_area_ha = configuracion_predeterminada()$max_area_ha_por_lote,
                                     max_lotes = configuracion_predeterminada()$max_lotes_espaciales,
                                     cache_dir = ruta_cache("consultas_ocurrencias"),
                                     reintentos = configuracion_predeterminada()$reintentos_api,
                                     pausa_entre_lotes_s = configuracion_predeterminada()$pausa_entre_lotes_s) {
  
  # 1. Preparar y validar el poligono provisto
  unidad_sf <- preparar_poligono_usuario(poligono = poligono, nombre = nombre)
  etiqueta_unidad <- if (!is.null(unidad_sf$unidad) && !is.na(unidad_sf$unidad[1])) unidad_sf$unidad[1] else "Poligono_Personalizado"
  
  validar_entrada_busqueda(unidad = etiqueta_unidad, grupo = grupo, limite = limite_por_api, nivel = "poligono")
  estrategia_espacial <- match.arg(estrategia_espacial)
  
  cli::cli_h1("B\u00fasqueda Integrada en Pol\u00edgono: {toupper(etiqueta_unidad)}")
  params_items <- character()
  if (!is.null(nombre_cientifico)) params_items <- c(params_items, paste0("Tax\u00f3n: ", nombre_cientifico))
  if (!is.null(grupo)) params_items <- c(params_items, paste0("Grupo: ", grupo))
  if (length(params_items) > 0) {
    cli::cli_ul(params_items)
  }
  
  # 2. Particionamiento adaptativo de poligono personalizado
  lotes_sf <- preparar_lotes_espaciales(unidad_sf, nivel = "poligono", nombre = etiqueta_unidad,
                                        departamento = NULL, estrategia_espacial = estrategia_espacial,
                                        max_area_ha = max_area_ha, max_lotes = max_lotes,
                                        nombre_cientifico = nombre_cientifico, grupo = grupo)
  clave_ejecucion <- nombre_seguro_cache(c("poligono", etiqueta_unidad, nombre_cientifico, grupo,
                                           limite_por_api, max_area_ha, max_lotes, tolerancia_simplificacion,
                                           estrategia_espacial))
  descarga <- consultar_lotes_espaciales(lotes_sf, nombre_cientifico, grupo, limite_por_api,
                                         tolerancia_simplificacion, cache_dir, reintentos,
                                         pausa_entre_lotes_s, clave_ejecucion)
  ocurrencias_combinadas <- descarga$ocurrencias
  if (nrow(ocurrencias_combinadas) == 0) {
    cli::cli_alert_warning("No se encontraron ocurrencias en ninguna de las bases de datos.")
  } else {
    cli::cli_alert_success("Consolidaci\u00f3n exitosa. Total de registros unificados: {.strong {nrow(ocurrencias_combinadas)}}")
  }
  
  # 5. Generar Estadisticas de Resumen
  n_gbif <- sum(ocurrencias_combinadas$source == "GBIF")
  n_inat <- sum(ocurrencias_combinadas$source == "iNaturalist")
  
  resumen <- list(
    nivel = "poligono",
    unidad = etiqueta_unidad,
    distrito = NA_character_,
    provincia = NA_character_,
    departamento = NA_character_,
    total_registros = nrow(ocurrencias_combinadas),
    registros_gbif = n_gbif,
    registros_inat = n_inat,
    limite_por_api = limite_por_api,
    gbif_total_reportado_api = NA_integer_,
    inat_total_reportado_api = NA_integer_,
    gbif_descarga_completa_api = FALSE,
    inat_descarga_completa_api = FALSE,
    lotes_espaciales = nrow(lotes_sf),
    fallos_lotes = descarga$fallos,
    nota_cobertura = if (is.null(limite_por_api)) "Se solicito descarga completa dentro de los limites tecnicos de las APIs." else "Se solicito una muestra limitada por API; la cobertura puede estar truncada."
  )
  
  cli::cli_h2("Resumen de Registros")
  cli::cli_bullets(c(
    "*" = "GBIF: {.val {n_gbif}} registro(s)",
    "*" = "iNaturalist: {.val {n_inat}} registro(s)",
    "v" = "Total consolidado: {.strong {nrow(ocurrencias_combinadas)}} registro(s)"
  ))
  if (length(descarga$fallos) > 0) {
    cli::cli_alert_danger("Se registraron fallos en {length(descarga$fallos)} lote(s):")
    cli::cli_ul(descarga$fallos)
  }
  
  resultado_obj <- list(
    unidad_sf = unidad_sf,
    distrito_sf = unidad_sf, # Alias para compatibilidad
    ocurrencias = ocurrencias_combinadas,
    resumen = resumen,
    parametros = list(
      nombre = etiqueta_unidad,
      nivel = "poligono",
      departamento = NULL,
      provincia = NULL,
      nombre_cientifico = nombre_cientifico,
      grupo = grupo,
      limite_por_api = limite_por_api,
      tolerancia_simplificacion_m = tolerancia_simplificacion,
      estrategia_espacial = estrategia_espacial,
      max_area_ha = max_area_ha,
      cache_dir = cache_dir
    )
  )
  
  # 6. Guardar Resultados en Archivos si se solicita explicitamente
  if (isTRUE(guardar_resultados) && nrow(ocurrencias_combinadas) > 0) {
    exportar_resultados(resultado_obj)
  }
  
  return(resultado_obj)
}
