# query_gbif.R
# Funciones para consultar ocurrencias de especies en la base de datos de GBIF.

#' Busca ocurrencias de GBIF dentro de un poligono
#'
#' Funcion de bajo nivel usada por las busquedas integradas. Convierte el limite
#' a WKT, lo simplifica si es necesario para la API de GBIF y luego vuelve a
#' filtrar localmente con el poligono exacto. Para uso habitual prefiera las
#' funciones `buscar_especies_*()`, que ademas integran iNaturalist y manejan
#' lotes/checkpoints.
#'
#' @param poligono_sf Objeto `sf` poligonal, preferiblemente en EPSG:4326. Debe
#'   contener una geometria valida; atributos administrativos son opcionales y
#'   se copian al resultado cuando existen.
#' @param nombre_cientifico `NULL` o cadena con un taxon. Se resuelve en la
#'   taxonomia seleccionada; por defecto se exige una coincidencia exacta.
#' @param grupo `NULL`, `"flora"` o `"fauna"`, que se traduce a los reinos
#'   Plantae y Animalia, respectivamente.
#' @param limite Entero positivo de hasta 100000, o `NULL`. Con entero solicita
#'   hasta ese numero de filas. Con `NULL` consulta primero el conteo y solo
#'   continua si no supera el limite de `rgbif::occ_search()` (100000).
#' @param tolerancia_simplificacion Numero no negativo de metros. Es la
#'   tolerancia inicial de simplificacion del WKT; se incrementa internamente
#'   cuando la geometria aun es demasiado extensa.
#' @param reintentos Entero positivo con intentos maximos para operaciones
#'   remotas transitorias, incluido el resolver taxonomico.
#' @param verbose Logico. Si es `TRUE`, muestra alertas de progreso.
#' @return `data.frame` con el esquema estandar de ocurrencias. Los atributos
#'   `api_total` y `api_complete` describen la respuesta de GBIF.
#' @noRd
buscar_gbif_por_poligono <- function(
  poligono_sf,
  nombre_cientifico = NULL,
  grupo = NULL,
  limite = 500,
  tolerancia_simplificacion = 100,
  reintentos = configuracion_predeterminada()$reintentos_api,
  taxonomia_gbif = c("col", "backbone"),
  coincidencia_taxonomica = c(
    "exacta",
    "permitir_fuzzy",
    "permitir_rango_superior"
  ),
  filtros_calidad_gbif = filtros_calidad_gbif_predeterminados(),
  resolucion_taxonomica = NULL,
  buscar_fun = rgbif::occ_search,
  verbose = TRUE
) {
  if (verbose) {
    cli::cli_alert_info("[GBIF] Iniciando b\u00fasqueda de ocurrencias...")
  }

  # 1. Simplificar el poligono de manera inteligente para la API (limite de longitud WKT <= 1500)
  poligono_api <- simplificar_para_api(
    poligono_sf,
    tolerancia_inicial_metros = tolerancia_simplificacion
  )
  wkt <- poligono_a_wkt(poligono_api)

  # Obtener nombres administrativos para registrar en el dataset
  nombre_distrito <- if (
    !is.null(poligono_sf$distrito) && !is.na(poligono_sf$distrito[1])
  ) {
    poligono_sf$distrito[1]
  } else {
    NA_character_
  }
  nombre_provincia <- if (
    !is.null(poligono_sf$provincia) && !is.na(poligono_sf$provincia[1])
  ) {
    poligono_sf$provincia[1]
  } else {
    NA_character_
  }
  nombre_departamento <- if (
    !is.null(poligono_sf$departamento) && !is.na(poligono_sf$departamento[1])
  ) {
    poligono_sf$departamento[1]
  } else {
    NA_character_
  }
  etiqueta_unidad <- if (!is.na(nombre_distrito)) {
    nombre_distrito
  } else if (!is.na(nombre_provincia)) {
    nombre_provincia
  } else {
    "Unidad seleccionada"
  }

  # 2. Resolver todos los identificadores en la misma taxonomia. En rgbif 3.9
  # las claves numericas fuerzan Backbone, por lo que nunca se combinan con COL.
  taxonomia_gbif <- match.arg(taxonomia_gbif)
  coincidencia_taxonomica <- match.arg(coincidencia_taxonomica)
  filtros <- normalizar_filtros_calidad_gbif(filtros_calidad_gbif)
  resolucion <- resolucion_taxonomica %||%
    resolver_taxonomia_gbif(
      nombre_cientifico = nombre_cientifico,
      grupo = grupo,
      checklist_key = normalizar_taxonomia_gbif(taxonomia_gbif),
      coincidencia = coincidencia_taxonomica,
      reintentos = reintentos
    )
  taxon_key <- resolucion$taxonKey
  kingdom_key <- resolucion$kingdomKey
  if (verbose && !is.null(resolucion$accepted_name)) {
    cli::cli_alert_success(
      "[GBIF] Taxon resuelto: {.strong {resolucion$accepted_name}} (Key: {taxon_key %||% kingdom_key}, coincidencia: {resolucion$matchType})."
    )
  }

  # 3. Ejecutar consulta
  limite_etiqueta <- if (is.null(limite)) "completo" else as.character(limite)
  if (verbose) {
    cli::cli_alert_info(
      "[GBIF] Consultando registros dentro del pol\u00edgono de {.strong {etiqueta_unidad}} (l\u00edmite: {.val {limite_etiqueta}})..."
    )
  }

  parametros <- list(
    geometry = wkt,
    hasCoordinate = TRUE,
    checklistKey = resolucion$checklistKey
  )
  parametros <- c(parametros, parametros_calidad_gbif(filtros))

  if (!is.null(taxon_key)) {
    parametros$taxonKey <- taxon_key
  }
  if (!is.null(kingdom_key)) {
    parametros$kingdomKey <- kingdom_key
  }

  total_api <- NA_integer_
  if (is.null(limite)) {
    conteo <- tryCatch(
      ejecutar_con_reintentos(
        function() do.call(buscar_fun, c(parametros, list(limit = 0))),
        reintentos,
        "GBIF conteo"
      ),
      error = function(e) NULL
    )
    total_api <- if (!is.null(conteo$meta$count)) {
      as.integer(conteo$meta$count)
    } else {
      NA_integer_
    }
    if (is.na(total_api)) {
      cli::cli_abort(
        "GBIF no devolvi\u00f3 el conteo de la consulta; no es posible verificar una descarga completa."
      )
    }
    if (total_api > 100000L) {
      cli::cli_abort(
        "GBIF reporta {format(total_api, big.mark = ',')} registros. occ_search solo permite 100000; solicite una descarga masiva citable con {.fn rgbif::occ_download} usando los mismos filtros."
      )
    }
    parametros$limit <- total_api
  } else {
    parametros$limit <- limite
  }

  res <- tryCatch(
    {
      ejecutar_con_reintentos(
        function() do.call(buscar_fun, parametros),
        reintentos,
        "GBIF ocurrencias"
      )
    },
    error = function(e) {
      cli::cli_alert_danger(
        "[GBIF] Error durante la llamada a {.fn occ_search}: {e$message}"
      )
      return(NULL)
    }
  )

  df_vacio <- schema_ocurrencias()

  if (is.null(res) || is.null(res$data) || nrow(res$data) == 0) {
    if (verbose) {
      cli::cli_alert_info("[GBIF] No se encontraron ocurrencias.")
    }
    attr(df_vacio, "api_total") <- if (is.na(total_api)) 0L else total_api
    attr(df_vacio, "api_complete") <- is.null(limite) && !is.na(total_api)
    attr(df_vacio, "gbif_taxonomia") <- resolucion
    attr(df_vacio, "gbif_filtros_calidad") <- filtros
    return(df_vacio)
  }

  datos_raw <- filtrar_calidad_gbif_local(res$data, filtros)

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
      if (
        col %in%
          c(
            "decimalLatitude",
            "decimalLongitude",
            "coordinateUncertaintyInMeters"
          )
      ) {
        datos_procesados[[col]] <- as.numeric(NA)
      } else {
        datos_procesados[[col]] <- as.character(NA)
      }
    }
  }
  datos_procesados$sourceURL <- ifelse(
    is.na(datos_procesados$sourceRecordID),
    NA_character_,
    paste0("https://www.gbif.org/occurrence/", datos_procesados$sourceRecordID)
  )

  if ("eventDate" %in% colnames(datos_procesados)) {
    datos_procesados$eventDate <- as.character(datos_procesados$eventDate)
  }

  datos_procesados$source <- "GBIF"
  datos_procesados$district <- nombre_distrito
  datos_procesados$province <- nombre_provincia
  datos_procesados$department <- nombre_departamento

  # 5. Filtrar espacialmente con el poligono exacto (poligono_sf) en R
  if (nrow(datos_procesados) > 0) {
    ocurrencias_sf <- tryCatch(
      {
        sf::st_as_sf(
          datos_procesados[
            is.finite(datos_procesados$decimalLongitude) &
              is.finite(datos_procesados$decimalLatitude),
          ],
          coords = c("decimalLongitude", "decimalLatitude"),
          crs = 4326,
          remove = FALSE
        )
      },
      error = function(e) {
        NULL
      }
    )

    if (!is.null(ocurrencias_sf)) {
      poligono_exacto <- sf::st_make_valid(poligono_sf)
      ocurrencias_sf <- sf::st_make_valid(ocurrencias_sf)
      interseccion <- sf::st_intersects(
        ocurrencias_sf,
        poligono_exacto,
        sparse = FALSE
      )
      datos_procesados <- sf::st_drop_geometry(ocurrencias_sf[
        interseccion[, 1],
      ])
    }
  }

  if (verbose) {
    cli::cli_alert_success(
      "[GBIF] B\u00fasqueda finalizada. Se filtraron {nrow(datos_procesados)} registro(s) que caen dentro del pol\u00edgono seleccionado."
    )
  }
  attr(datos_procesados, "api_total") <- if (is.na(total_api)) {
    res$meta$count
  } else {
    total_api
  }
  attr(datos_procesados, "api_complete") <- is.null(limite) &&
    !is.na(total_api) &&
    nrow(res$data) == total_api
  attr(datos_procesados, "gbif_taxonomia") <- resolucion
  attr(datos_procesados, "gbif_filtros_calidad") <- filtros

  return(datos_procesados)
}
