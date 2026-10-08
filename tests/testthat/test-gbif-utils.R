test_that("los filtros GBIF predeterminados son conservadores y modificables", {
  filtros <- peruocc::filtros_calidad_gbif_predeterminados()

  expect_identical(filtros$has_geospatial_issue, FALSE)
  expect_identical(filtros$occurrence_status, "PRESENT")
  expect_setequal(
    filtros$excluir_basis_of_record,
    c("FOSSIL_SPECIMEN", "LIVING_SPECIMEN")
  )
  expect_identical(
    peruocc:::normalizar_filtros_calidad_gbif(list(
      license = "CC_BY_4_0"
    ))$license,
    "CC_BY_4_0"
  )
})

test_that("la resolución COL usa claves alfanuméricas para grupo y taxón", {
  llamadas <- list()
  simulador_match <- function(
    name,
    kingdom = NULL,
    rank = NULL,
    checklistKey = NULL
  ) {
    llamadas[[length(llamadas) + 1L]] <<- list(
      name = name,
      kingdom = kingdom,
      rank = rank,
      checklistKey = checklistKey
    )
    data.frame(
      usageKey = if (identical(name, "Plantae")) "B" else "9WLSS",
      scientificName = name,
      matchType = "EXACT",
      rank = if (identical(name, "Plantae")) "KINGDOM" else "SPECIES"
    )
  }

  reino <- peruocc:::resolver_taxonomia_gbif(
    grupo = "flora",
    match_fun = simulador_match
  )
  especie <- peruocc:::resolver_taxonomia_gbif(
    nombre_cientifico = "Puma concolor",
    grupo = "fauna",
    match_fun = simulador_match
  )

  expect_identical(reino$kingdomKey, "B")
  expect_identical(reino$checklistKey, peruocc:::gbif_col_xr_key)
  expect_null(especie$kingdomKey)
  expect_identical(especie$taxonKey, "9WLSS")
  expect_identical(llamadas[[2]]$kingdom, "Animalia")
})

test_that("los filtros locales retiran bases excluidas e incertidumbre excesiva", {
  datos <- data.frame(
    basisOfRecord = c(
      "PRESERVED_SPECIMEN",
      "FOSSIL_SPECIMEN",
      "HUMAN_OBSERVATION",
      "OBSERVATION"
    ),
    coordinateUncertaintyInMeters = c(50, 10, 500, NA_real_),
    distanceFromCentroidInMeters = c(500, 500, 500, 500),
    stringsAsFactors = FALSE
  )
  filtros <- peruocc:::normalizar_filtros_calidad_gbif(list(
    incertidumbre_max_m = 100,
    permitir_incertidumbre_desconocida = TRUE
  ))

  filtrados <- peruocc:::filtrar_calidad_gbif_local(datos, filtros)
  expect_identical(
    filtrados$basisOfRecord,
    c("PRESERVED_SPECIMEN", "OBSERVATION")
  )
})

test_that("los atajos de calidad sustituyen solamente los filtros solicitados", {
  filtros <- peruocc:::aplicar_atajos_calidad_gbif(
    peruocc::filtros_calidad_gbif_predeterminados(),
    excluir_fosiles = FALSE,
    excluir_especimenes_vivos = TRUE,
    incertidumbre_max_m = 1000,
    licencias_gbif = "CC0_1_0"
  )

  expect_false("FOSSIL_SPECIMEN" %in% filtros$excluir_basis_of_record)
  expect_true("LIVING_SPECIMEN" %in% filtros$excluir_basis_of_record)
  expect_identical(filtros$incertidumbre_max_m, 1000)
  expect_identical(filtros$license, "CC0_1_0")
})

test_that("las interfaces públicas incluyen controles GBIF 3.9", {
  argumentos <- names(formals(peruocc::buscar_especies_peru))
  controles <- c(
    "taxonomia_gbif",
    "coincidencia_taxonomica",
    "filtros_calidad_gbif",
    "excluir_incidentes_geoespaciales",
    "excluir_fosiles",
    "incertidumbre_max_m"
  )
  expect_setequal(
    controles,
    intersect(controles, argumentos)
  )
  expect_identical(
    eval(formals(peruocc::crear_descarga_gbif)$formato),
    c("SIMPLE_PARQUET", "SIMPLE_CSV", "DWCA")
  )
  expect_identical(
    formals(peruocc::crear_descarga_gbif)$tolerancia_simplificacion,
    100
  )
})

test_that("la recuperacion crea el directorio antes de descargar", {
  destino <- tempfile("gbif-descarga-")
  on.exit(unlink(destino, recursive = TRUE), add = TRUE)
  llamada_espera <- NULL
  llamada_descarga <- NULL

  archivo <- peruocc:::recuperar_archivo_descarga_gbif(
    clave = "0016731-260928105237408",
    dir_salida = destino,
    esperar = TRUE,
    esperar_fun = function(clave) {
      llamada_espera <<- clave
      invisible(NULL)
    },
    obtener_fun = function(clave, path) {
      llamada_descarga <<- list(clave = clave, path = path)
      file.path(path, paste0(clave, ".zip"))
    }
  )

  expect_identical(dir.exists(destino), TRUE)
  expect_identical(llamada_espera, "0016731-260928105237408")
  expect_identical(llamada_descarga$clave, "0016731-260928105237408")
  expect_identical(llamada_descarga$path, destino)
  expect_identical(archivo, file.path(destino, "0016731-260928105237408.zip"))
})

test_that("una clave se puede extraer de resultados de descarga", {
  resultado <- list(clave = "0016731-260928105237408")
  expect_identical(
    peruocc:::extraer_clave_descarga_gbif(resultado),
    "0016731-260928105237408"
  )
})

test_that("los fragmentos Parquet vacios se excluyen", {
  directorio <- tempfile("gbif-parquet-")
  on.exit(unlink(directorio, recursive = TRUE), add = TRUE)
  ruta_parquet <- file.path(directorio, "occurrence.parquet")
  dir.create(ruta_parquet, recursive = TRUE)
  file.create(file.path(ruta_parquet, "000000"))
  writeBin(
    as.raw(c(80, 65, 82, 49)),
    file.path(ruta_parquet, "000001")
  )

  archivos <- peruocc:::archivos_parquet_gbif_validos(directorio)

  expect_identical(archivos, file.path(ruta_parquet, "000001"))
})
