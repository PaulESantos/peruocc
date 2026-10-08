# Helpers for rgbif 3.9+ taxonomy, quality filters, and mediated downloads.

gbif_col_xr_key <- "7ddf754f-d193-4cc9-b351-99906754a03b"
gbif_backbone_key <- "d7dddbf4-2cf0-4f39-9b2a-bb099caae36c"

#' Filtros de calidad predeterminados para consultas GBIF
#'
#' Devuelve una lista modificable para `filtros_calidad_gbif`. Los valores
#' predeterminados excluyen incidencias geoespaciales conocidas, registros
#' ausentes, fosiles y especimenes vivos. Los umbrales de incertidumbre y de
#' distancia a centroides son optativos porque esos campos pueden estar vacios.
#'
#' @return Lista de filtros compatible con `buscar_especies_*()` y
#'   [crear_descarga_gbif()].
#' @examples
#' filtros <- filtros_calidad_gbif_predeterminados()
#' names(filtros)
#' @export
filtros_calidad_gbif_predeterminados <- function() {
  list(
    has_geospatial_issue = FALSE,
    occurrence_status = "PRESENT",
    excluir_basis_of_record = c("FOSSIL_SPECIMEN", "LIVING_SPECIMEN"),
    incertidumbre_max_m = NULL,
    permitir_incertidumbre_desconocida = TRUE,
    distancia_min_centroide_m = NULL,
    license = NULL
  )
}

normalizar_taxonomia_gbif <- function(taxonomia = c("col", "backbone")) {
  taxonomia <- match.arg(taxonomia)
  if (identical(taxonomia, "col")) gbif_col_xr_key else gbif_backbone_key
}

normalizar_filtros_calidad_gbif <- function(
  filtros = filtros_calidad_gbif_predeterminados()
) {
  if (is.null(filtros)) {
    return(list())
  }
  if (!is.list(filtros)) {
    cli::cli_abort(
      "{.arg filtros_calidad_gbif} debe ser una lista o {.val NULL}."
    )
  }

  predeterminados <- filtros_calidad_gbif_predeterminados()
  desconocidos <- setdiff(names(filtros), names(predeterminados))
  if (length(desconocidos) > 0) {
    cli::cli_abort("Filtros GBIF desconocidos: {.val {desconocidos}}.")
  }
  utils::modifyList(predeterminados, filtros)
}

validar_logico_opcional <- function(x, nombre) {
  if (!is.null(x) && (!is.logical(x) || length(x) != 1L || is.na(x))) {
    cli::cli_abort(
      "{.arg {nombre}} debe ser {.val TRUE}, {.val FALSE} o {.val NULL}."
    )
  }
}

aplicar_atajos_calidad_gbif <- function(
  filtros,
  excluir_incidentes_geoespaciales = NULL,
  solo_ocurrencias_presentes = NULL,
  excluir_fosiles = NULL,
  excluir_especimenes_vivos = NULL,
  incertidumbre_max_m = NULL,
  permitir_incertidumbre_desconocida = NULL,
  distancia_min_centroide_m = NULL,
  licencias_gbif = NULL
) {
  filtros <- normalizar_filtros_calidad_gbif(filtros)
  for (nombre in c(
    "excluir_incidentes_geoespaciales",
    "solo_ocurrencias_presentes",
    "excluir_fosiles",
    "excluir_especimenes_vivos",
    "permitir_incertidumbre_desconocida"
  )) {
    validar_logico_opcional(get(nombre), nombre)
  }
  if (
    !is.null(incertidumbre_max_m) &&
      (!is.numeric(incertidumbre_max_m) ||
        length(incertidumbre_max_m) != 1L ||
        is.na(incertidumbre_max_m) ||
        incertidumbre_max_m < 0)
  ) {
    cli::cli_abort(
      "{.arg incertidumbre_max_m} debe ser un numero no negativo o {.val NULL}."
    )
  }
  if (
    !is.null(distancia_min_centroide_m) &&
      (!is.numeric(distancia_min_centroide_m) ||
        length(distancia_min_centroide_m) != 1L ||
        is.na(distancia_min_centroide_m) ||
        distancia_min_centroide_m < 0)
  ) {
    cli::cli_abort(
      "{.arg distancia_min_centroide_m} debe ser un numero no negativo o {.val NULL}."
    )
  }

  if (!is.null(excluir_incidentes_geoespaciales)) {
    filtros$has_geospatial_issue <- if (excluir_incidentes_geoespaciales) {
      FALSE
    } else {
      NULL
    }
  }
  if (!is.null(solo_ocurrencias_presentes)) {
    filtros$occurrence_status <- if (solo_ocurrencias_presentes) {
      "PRESENT"
    } else {
      NULL
    }
  }
  excluir <- filtros$excluir_basis_of_record %||% character()
  if (!is.null(excluir_fosiles)) {
    excluir <- if (excluir_fosiles) {
      unique(c(excluir, "FOSSIL_SPECIMEN"))
    } else {
      setdiff(excluir, "FOSSIL_SPECIMEN")
    }
  }
  if (!is.null(excluir_especimenes_vivos)) {
    excluir <- if (excluir_especimenes_vivos) {
      unique(c(excluir, "LIVING_SPECIMEN"))
    } else {
      setdiff(excluir, "LIVING_SPECIMEN")
    }
  }
  filtros$excluir_basis_of_record <- excluir
  if (!is.null(incertidumbre_max_m)) {
    filtros$incertidumbre_max_m <- incertidumbre_max_m
  }
  if (!is.null(permitir_incertidumbre_desconocida)) {
    filtros$permitir_incertidumbre_desconocida <- permitir_incertidumbre_desconocida
  }
  if (!is.null(distancia_min_centroide_m)) {
    filtros$distancia_min_centroide_m <- distancia_min_centroide_m
  }
  if (!is.null(licencias_gbif)) {
    filtros$license <- licencias_gbif
  }
  filtros
}

nombre_reino_gbif <- function(grupo) {
  if (is.null(grupo)) {
    return(NULL)
  }
  switch(tolower(trimws(grupo)), flora = "Plantae", fauna = "Animalia")
}

resolver_taxonomia_gbif <- function(
  nombre_cientifico = NULL,
  grupo = NULL,
  checklist_key = gbif_col_xr_key,
  coincidencia = c("exacta", "permitir_fuzzy", "permitir_rango_superior"),
  reintentos = configuracion_predeterminada()$reintentos_api,
  match_fun = rgbif::name_backbone
) {
  coincidencia <- match.arg(coincidencia)
  reino <- nombre_reino_gbif(grupo)

  if (is.null(nombre_cientifico) || !nzchar(trimws(nombre_cientifico))) {
    if (is.null(reino)) {
      return(list(
        checklistKey = checklist_key,
        taxonKey = NULL,
        kingdomKey = NULL,
        requested_name = NULL,
        accepted_name = NULL,
        matchType = NULL,
        rank = NULL
      ))
    }
    resultado <- ejecutar_con_reintentos(
      function() {
        match_fun(name = reino, rank = "KINGDOM", checklistKey = checklist_key)
      },
      reintentos,
      "GBIF taxonomia"
    )
    if (
      is.null(resultado$usageKey) ||
        !identical(toupper(resultado$matchType), "EXACT")
    ) {
      cli::cli_abort(
        "GBIF no pudo resolver el reino {.val {reino}} en la taxonomia seleccionada."
      )
    }
    return(list(
      checklistKey = checklist_key,
      taxonKey = NULL,
      kingdomKey = as.character(resultado$usageKey),
      requested_name = reino,
      accepted_name = resultado$scientificName,
      matchType = resultado$matchType,
      rank = resultado$rank
    ))
  }

  resultado <- ejecutar_con_reintentos(
    function() {
      match_fun(
        name = nombre_cientifico,
        kingdom = reino,
        checklistKey = checklist_key
      )
    },
    reintentos,
    "GBIF taxonomia"
  )
  tipo <- toupper(resultado$matchType %||% "NONE")
  permitido <- identical(tipo, "EXACT") ||
    (identical(tipo, "FUZZY") && coincidencia == "permitir_fuzzy") ||
    (identical(tipo, "HIGHERRANK") && coincidencia == "permitir_rango_superior")

  if (is.null(resultado$usageKey) || !permitido) {
    ayuda <- switch(
      tipo,
      FUZZY = "Use `coincidencia_taxonomica = 'permitir_fuzzy'` solo tras revisar el nombre aceptado.",
      HIGHERRANK = "Use `coincidencia_taxonomica = 'permitir_rango_superior'` si una busqueda de rango superior es intencional.",
      "Revise la ortografia o proporcione la autoria taxonomica."
    )
    cli::cli_abort(c(
      "x" = "GBIF no produjo una coincidencia exacta para {.val {nombre_cientifico}} (tipo: {.val {tipo}}).",
      "i" = ayuda
    ))
  }

  list(
    checklistKey = checklist_key,
    taxonKey = as.character(resultado$usageKey),
    # Cuando se filtra por un taxon, el reino es redundante. Omitirlo evita
    # mezclar identificadores de taxonomias distintas.
    kingdomKey = NULL,
    requested_name = nombre_cientifico,
    accepted_name = resultado$scientificName,
    matchType = resultado$matchType,
    rank = resultado$rank
  )
}

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || is.na(x[1])) y else x
}

parametros_calidad_gbif <- function(filtros) {
  parametros <- list()
  if (!is.null(filtros$has_geospatial_issue)) {
    parametros$hasGeospatialIssue <- filtros$has_geospatial_issue
  }
  if (!is.null(filtros$occurrence_status)) {
    parametros$occurrenceStatus <- filtros$occurrence_status
  }
  if (!is.null(filtros$license)) {
    parametros$license <- filtros$license
  }
  parametros
}

filtrar_calidad_gbif_local <- function(datos, filtros) {
  if (nrow(datos) == 0) {
    return(datos)
  }
  conservar <- rep(TRUE, nrow(datos))

  if (
    length(filtros$excluir_basis_of_record) > 0 &&
      "basisOfRecord" %in% names(datos)
  ) {
    conservar <- conservar &
      !(datos$basisOfRecord %in% filtros$excluir_basis_of_record)
  }
  if (
    !is.null(filtros$incertidumbre_max_m) &&
      "coordinateUncertaintyInMeters" %in% names(datos)
  ) {
    incertidumbre <- suppressWarnings(as.numeric(
      datos$coordinateUncertaintyInMeters
    ))
    es_desconocida <- is.na(incertidumbre)
    conservar <- conservar &
      (incertidumbre <= filtros$incertidumbre_max_m |
        if (isTRUE(filtros$permitir_incertidumbre_desconocida)) {
          es_desconocida
        } else {
          FALSE
        })
  }
  if (
    !is.null(filtros$distancia_min_centroide_m) &&
      "distanceFromCentroidInMeters" %in% names(datos)
  ) {
    distancia <- suppressWarnings(as.numeric(
      datos$distanceFromCentroidInMeters
    ))
    conservar <- conservar &
      !is.na(distancia) &
      distancia >= filtros$distancia_min_centroide_m
  }
  datos[conservar, , drop = FALSE]
}

predicados_descarga_gbif <- function(wkt, taxonomia, filtros) {
  predicados <- list(
    rgbif::pred_within(wkt),
    rgbif::pred("hasCoordinate", TRUE)
  )
  if (!is.null(taxonomia$taxonKey)) {
    predicados[[length(predicados) + 1L]] <- rgbif::pred(
      "taxonKey",
      taxonomia$taxonKey,
      checklistKey = taxonomia$checklistKey
    )
  }
  if (!is.null(taxonomia$kingdomKey)) {
    predicados[[length(predicados) + 1L]] <- rgbif::pred(
      "kingdomKey",
      taxonomia$kingdomKey,
      checklistKey = taxonomia$checklistKey
    )
  }
  if (!is.null(filtros$has_geospatial_issue)) {
    predicados[[length(predicados) + 1L]] <- rgbif::pred(
      "hasGeospatialIssue",
      filtros$has_geospatial_issue
    )
  }
  if (!is.null(filtros$occurrence_status)) {
    predicados[[length(predicados) + 1L]] <- rgbif::pred(
      "occurrenceStatus",
      filtros$occurrence_status
    )
  }
  if (length(filtros$excluir_basis_of_record) > 0) {
    predicados[[length(predicados) + 1L]] <- rgbif::pred_not(
      rgbif::pred_in("basisOfRecord", filtros$excluir_basis_of_record)
    )
  }
  if (!is.null(filtros$incertidumbre_max_m)) {
    predicados[[length(predicados) + 1L]] <- rgbif::pred_lte(
      "coordinateUncertaintyInMeters",
      filtros$incertidumbre_max_m
    )
  }
  if (!is.null(filtros$distancia_min_centroide_m)) {
    predicados[[length(predicados) + 1L]] <- rgbif::pred_gte(
      "distanceFromCentroidInMeters",
      filtros$distancia_min_centroide_m
    )
  }
  if (!is.null(filtros$license)) {
    predicados[[length(predicados) + 1L]] <- if (
      length(filtros$license) == 1L
    ) {
      rgbif::pred("license", filtros$license)
    } else {
      rgbif::pred_in("license", filtros$license)
    }
  }
  predicados
}

preparar_poligono_descarga_gbif <- function(
  poligono_sf,
  tolerancia_inicial_metros,
  max_caracteres_wkt = 1500L
) {
  wkt_original <- sf::st_as_text(sf::st_geometry(poligono_sf)[[1]])
  if (nchar(wkt_original) <= max_caracteres_wkt) {
    return(poligono_sf)
  }

  tolerancia_metros <- tolerancia_inicial_metros
  for (iteracion in seq_len(6L)) {
    simplificado <- simplificar_poligono(
      poligono_sf,
      tolerancia_metros = tolerancia_metros
    )
    wkt_simplificado <- sf::st_as_text(sf::st_geometry(simplificado)[[1]])
    if (nchar(wkt_simplificado) <= max_caracteres_wkt) {
      cli::cli_alert_info(
        "[GBIF] Poligono simplificado a {tolerancia_metros} m para la descarga."
      )
      return(simplificado)
    }
    tolerancia_metros <- tolerancia_metros * 3
  }

  cli::cli_abort(
    paste0(
      "El poligono no se pudo simplificar por debajo de ",
      "{max_caracteres_wkt} caracteres WKT sin sustituirlo por su caja ",
      "delimitadora. Dividalo en unidades mas pequenas o aumente ",
      "{.arg tolerancia_simplificacion}."
    )
  )
}

extraer_clave_descarga_gbif <- function(descarga) {
  clave <- if (is.list(descarga) && !is.null(descarga$clave)) {
    descarga$clave
  } else if (is.list(descarga) && !is.null(descarga$key)) {
    descarga$key
  } else {
    descarga
  }
  if (!is.character(clave) || length(clave) != 1L || !nzchar(clave)) {
    cli::cli_abort(
      "{.arg descarga} debe ser una clave GBIF o un resultado de {.fn crear_descarga_gbif}."
    )
  }
  clave
}

recuperar_archivo_descarga_gbif <- function(
  clave,
  dir_salida,
  esperar,
  esperar_fun = rgbif::occ_download_wait,
  obtener_fun = rgbif::occ_download_get
) {
  if (
    !is.character(dir_salida) ||
      length(dir_salida) != 1L ||
      !nzchar(trimws(dir_salida))
  ) {
    cli::cli_abort(
      "{.arg dir_salida} debe ser un directorio de destino no vacio."
    )
  }
  dir.create(dir_salida, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(dir_salida)) {
    cli::cli_abort(
      "No se pudo crear el directorio de destino {.file {dir_salida}}."
    )
  }

  if (isTRUE(esperar)) {
    cli::cli_alert_info(
      "[GBIF] Esperando que finalice la descarga {.val {clave}}..."
    )
    esperar_fun(clave)
  }
  cli::cli_alert_info(
    "[GBIF] Descargando el archivo en {.file {dir_salida}}..."
  )
  archivo <- obtener_fun(clave, path = dir_salida)
  cli::cli_alert_success("[GBIF] Archivo descargado: {.file {archivo}}")
  archivo
}

#' Crea una descarga reproducible de ocurrencias desde GBIF
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Envia una descarga mediada por GBIF para un poligono amplio. A diferencia de
#' `buscar_especies_*()`, este flujo no devuelve una muestra inmediata: genera
#' una clave de descarga y DOI citable. El formato Parquet es la opcion
#' predeterminada para volumenes grandes; requiere `arrow` solo para leer el
#' archivo posteriormente, no para solicitarlo.
#'
#' @param poligono Objeto espacial aceptado por [preparar_poligono_usuario()].
#' @param nombre_cientifico `NULL` o nombre cientifico a resolver en GBIF.
#' @param grupo `NULL`, `"flora"` o `"fauna"`.
#' @param taxonomia `"col"` (predeterminado) o `"backbone"`.
#' @param coincidencia_taxonomica Politica para coincidencias no exactas.
#' @param filtros_calidad_gbif Lista creada por [filtros_calidad_gbif_predeterminados()].
#' @param excluir_incidentes_geoespaciales Excluye incidencias espaciales
#'   conocidas cuando es `TRUE`; con `FALSE` no las filtra.
#' @param solo_ocurrencias_presentes Conserva solo registros `PRESENT` cuando
#'   es `TRUE`; con `FALSE` no aplica ese filtro.
#' @param excluir_fosiles,excluir_especimenes_vivos Excluyen esos tipos de
#'   registro cuando son `TRUE`.
#' @param incertidumbre_max_m Maxima incertidumbre espacial en metros.
#' @param permitir_incertidumbre_desconocida Conserva registros sin valor de
#'   incertidumbre al aplicar `incertidumbre_max_m`.
#' @param distancia_min_centroide_m Distancia minima a un centroide, en metros.
#' @param licencias_gbif Licencia o vector de licencias aceptadas por GBIF.
#' @param formato Formato solicitado a GBIF.
#' @param esperar Si es `TRUE`, espera a que GBIF termine y descarga el ZIP.
#' @param dir_salida Directorio opcional para el manifiesto y, cuando
#'   `esperar = TRUE`, directorio obligatorio para el ZIP.
#' @param tolerancia_simplificacion Tolerancia inicial, en metros, para
#'   simplificar poligonos con WKT extenso. La simplificacion conserva el
#'   poligono; nunca lo reemplaza por una caja delimitadora.
#' @param user,pwd,email Credenciales GBIF opcionales. Es preferible definir
#'   `GBIF_USER`, `GBIF_PWD` y `GBIF_EMAIL` como variables de entorno.
#' @param reintentos Entero positivo con el numero maximo de intentos para las
#'   operaciones remotas de GBIF.
#' @return Lista con la clave, DOI, cita, resolucion taxonomica y, opcionalmente,
#'   la ruta del archivo descargado.
#' @examples
#' \dontrun{
#' if (requireNamespace("sf", quietly = TRUE)) {
#'   poligono <- sf::st_sfc(
#'     sf::st_polygon(list(matrix(
#'       c(-77.05, -12.13, -77.01, -12.13, -77.01, -12.10, -77.05, -12.10, -77.05, -12.13),
#'       ncol = 2, byrow = TRUE
#'     ))),
#'     crs = 4326
#'   )
#'   # Requiere credenciales GBIF (GBIF_USER, GBIF_PWD, GBIF_EMAIL)
#'   crear_descarga_gbif(poligono, grupo = "aves")
#' }
#' }
#' @export
crear_descarga_gbif <- function(
  poligono,
  nombre_cientifico = NULL,
  grupo = NULL,
  taxonomia = c("col", "backbone"),
  coincidencia_taxonomica = c(
    "exacta",
    "permitir_fuzzy",
    "permitir_rango_superior"
  ),
  filtros_calidad_gbif = filtros_calidad_gbif_predeterminados(),
  excluir_incidentes_geoespaciales = NULL,
  solo_ocurrencias_presentes = NULL,
  excluir_fosiles = NULL,
  excluir_especimenes_vivos = NULL,
  incertidumbre_max_m = NULL,
  permitir_incertidumbre_desconocida = NULL,
  distancia_min_centroide_m = NULL,
  licencias_gbif = NULL,
  formato = c("SIMPLE_PARQUET", "SIMPLE_CSV", "DWCA"),
  esperar = FALSE,
  dir_salida = NULL,
  tolerancia_simplificacion = 100,
  user = NULL,
  pwd = NULL,
  email = NULL,
  reintentos = configuracion_predeterminada()$reintentos_api
) {
  taxonomia <- match.arg(taxonomia)
  coincidencia_taxonomica <- match.arg(coincidencia_taxonomica)
  formato <- match.arg(formato)
  validar_entrada_busqueda(
    "descarga_gbif",
    grupo = grupo,
    limite = NULL,
    nivel = "poligono"
  )
  lifecycle::signal_stage("experimental", "crear_descarga_gbif()")

  if (
    !is.numeric(tolerancia_simplificacion) ||
      length(tolerancia_simplificacion) != 1L ||
      is.na(tolerancia_simplificacion) ||
      tolerancia_simplificacion <= 0
  ) {
    cli::cli_abort(
      "{.arg tolerancia_simplificacion} debe ser un numero positivo de metros."
    )
  }
  if (isTRUE(esperar) && is.null(dir_salida)) {
    cli::cli_abort(
      "Con {.arg esperar = TRUE} debe indicar {.arg dir_salida} para guardar el archivo."
    )
  }

  unidad_sf <- preparar_poligono_usuario(poligono)
  unidad_sf <- asegurar_orientacion_antihoraria(sf::st_make_valid(unidad_sf))
  poligono_descarga <- preparar_poligono_descarga_gbif(
    unidad_sf,
    tolerancia_inicial_metros = tolerancia_simplificacion
  )
  wkt <- poligono_a_wkt(poligono_descarga)
  filtros <- aplicar_atajos_calidad_gbif(
    filtros_calidad_gbif,
    excluir_incidentes_geoespaciales,
    solo_ocurrencias_presentes,
    excluir_fosiles,
    excluir_especimenes_vivos,
    incertidumbre_max_m,
    permitir_incertidumbre_desconocida,
    distancia_min_centroide_m,
    licencias_gbif
  )
  resolucion <- resolver_taxonomia_gbif(
    nombre_cientifico,
    grupo,
    normalizar_taxonomia_gbif(taxonomia),
    coincidencia_taxonomica,
    reintentos
  )
  predicados <- predicados_descarga_gbif(wkt, resolucion, filtros)
  argumentos <- c(
    predicados,
    list(format = formato, checklistKey = resolucion$checklistKey)
  )
  credenciales <- list(user = user, pwd = pwd, email = email)
  argumentos <- c(
    argumentos,
    credenciales[!vapply(credenciales, is.null, logical(1))]
  )

  cli::cli_alert_info(
    "[GBIF] Solicitando descarga mediada en formato {.val {formato}}..."
  )
  descarga <- ejecutar_con_reintentos(
    function() do.call(rgbif::occ_download, argumentos),
    reintentos,
    "GBIF descarga"
  )
  clave_descarga <- if (is.list(descarga) && !is.null(descarga$key)) {
    descarga$key
  } else {
    as.character(descarga)[1]
  }
  resultado <- list(
    clave = clave_descarga,
    doi = attr(descarga, "doi"),
    cita = attr(descarga, "citation"),
    formato = formato,
    taxonomia = resolucion,
    filtros_calidad_gbif = filtros,
    descarga = descarga,
    archivo = NULL,
    manifiesto = NULL
  )
  if (!is.null(dir_salida)) {
    dir.create(dir_salida, recursive = TRUE, showWarnings = FALSE)
    ruta_manifiesto <- file.path(
      dir_salida,
      paste0("descarga_gbif_", resultado$clave, ".json")
    )
    jsonlite::write_json(
      list(
        download_key = resultado$clave,
        doi = resultado$doi,
        citation = resultado$cita,
        format = resultado$formato,
        taxonomy = resultado$taxonomia,
        quality_filters = resultado$filtros_calidad_gbif,
        polygon_wkt = wkt,
        simplification_tolerance_m = tolerancia_simplificacion
      ),
      ruta_manifiesto,
      pretty = TRUE,
      auto_unbox = TRUE,
      null = "null"
    )
    resultado$manifiesto <- ruta_manifiesto
    cli::cli_alert_success(
      "[GBIF] Manifiesto de la solicitud guardado en {.file {ruta_manifiesto}}."
    )
  }
  if (isTRUE(esperar)) {
    resultado$archivo <- recuperar_archivo_descarga_gbif(
      clave_descarga,
      dir_salida,
      esperar = TRUE
    )
  } else {
    cli::cli_alert_info(
      "[GBIF] Solicitud creada: {.val {clave_descarga}}. Use {.fn recuperar_descarga_gbif} cuando GBIF finalice."
    )
  }
  class(resultado) <- "peruocc_descarga_gbif"
  resultado
}

#' Recupera una descarga GBIF ya solicitada
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Espera opcionalmente a que GBIF termine una descarga asincrona y guarda el
#' ZIP resultante en un directorio indicado de forma explicita. No crea una
#' solicitud nueva ni escribe en el directorio de trabajo.
#'
#' @param descarga Clave de descarga de GBIF o resultado de
#'   [crear_descarga_gbif()].
#' @param dir_salida Directorio donde se guardara el ZIP. Se crea si no existe.
#' @param esperar Si es `TRUE`, espera la finalizacion de GBIF antes de descargar.
#' @return Lista con `clave`, `archivo` y `directorio`.
#' @examples
#' \dontrun{
#' recuperada <- recuperar_descarga_gbif(
#'   "0016731-260928105237408", dir_salida = "datos/gbif"
#' )
#' }
#' @export
recuperar_descarga_gbif <- function(descarga, dir_salida, esperar = TRUE) {
  lifecycle::signal_stage("experimental", "recuperar_descarga_gbif()")
  clave <- extraer_clave_descarga_gbif(descarga)
  archivo <- recuperar_archivo_descarga_gbif(
    clave,
    dir_salida,
    esperar = esperar
  )
  list(
    clave = clave,
    archivo = archivo,
    directorio = normalizePath(dir_salida, winslash = "/", mustWork = TRUE)
  )
}

#' Abre archivos Parquet de una descarga GBIF
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Abre de forma perezosa los archivos Parquet extraidos de una descarga GBIF.
#' Los fragmentos vacios se excluyen automaticamente, pues GBIF puede incluirlos
#' en descargas particionadas.
#'
#' @param ruta Directorio extraido de una descarga `SIMPLE_PARQUET` o un vector
#'   de archivos Parquet.
#' @return Un `arrow::Dataset`.
#' @examples
#' \dontrun{
#' registros <- leer_descarga_gbif("datos/gbif/parquet")
#' }
#' @export
leer_descarga_gbif <- function(ruta) {
  lifecycle::signal_stage("experimental", "leer_descarga_gbif()")
  if (!requireNamespace("arrow", quietly = TRUE)) {
    cli::cli_abort(
      "Para leer archivos Parquet instale el paquete sugerido {.pkg arrow}."
    )
  }
  archivos <- archivos_parquet_gbif_validos(ruta)
  arrow::open_dataset(archivos, format = "parquet")
}

archivos_parquet_gbif_validos <- function(ruta) {
  if (!is.character(ruta) || length(ruta) < 1L || any(!nzchar(ruta))) {
    cli::cli_abort(
      "{.arg ruta} debe ser un directorio o vector no vacio de archivos Parquet."
    )
  }
  if (length(ruta) == 1L && dir.exists(ruta)) {
    archivos <- list.files(
      ruta,
      recursive = TRUE,
      full.names = TRUE,
      include.dirs = FALSE
    )
  } else {
    archivos <- ruta
  }
  archivos <- archivos[grepl(".parquet", archivos, fixed = TRUE)]
  existentes <- file.exists(archivos) & !dir.exists(archivos)
  archivos <- archivos[existentes]
  tamanos <- file.info(archivos)$size
  validos <- archivos[!is.na(tamanos) & tamanos > 0]

  if (length(validos) == 0) {
    cli::cli_abort(
      "No se encontraron archivos Parquet no vacios en {.file {ruta}}."
    )
  }
  if (length(validos) < length(archivos)) {
    cli::cli_alert_warning(
      "[GBIF] Se omitieron {length(archivos) - length(validos)} fragmento(s) Parquet vacio(s)."
    )
  }
  validos
}

#' @rdname crear_descarga_gbif
#' @param ... Argumentos que se reenvian a [crear_descarga_gbif()].
#' @export
solicitar_descarga_gbif <- function(...) {
  .Deprecated("crear_descarga_gbif")
  crear_descarga_gbif(...)
}
