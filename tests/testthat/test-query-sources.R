poligono_prueba_fuentes <- function() {
  coords <- matrix(
    c(
      -77.10,
      -12.10,
      -77.00,
      -12.10,
      -77.00,
      -12.00,
      -77.10,
      -12.00,
      -77.10,
      -12.10
    ),
    ncol = 2,
    byrow = TRUE
  )
  sf::st_as_sf(sf::st_sfc(sf::st_polygon(list(coords)), crs = 4326))
}

test_that("la consulta GBIF usa claves COL y aplica calidad local", {
  llamadas <- list()
  buscar_falso <- function(...) {
    argumentos <- list(...)
    llamadas[[length(llamadas) + 1L]] <<- argumentos
    list(
      meta = list(count = 2L),
      data = data.frame(
        key = c("uno", "dos"),
        scientificName = c("Especie valida", "Fosil"),
        decimalLatitude = c(-12.05, -12.05),
        decimalLongitude = c(-77.05, -77.06),
        basisOfRecord = c("PRESERVED_SPECIMEN", "FOSSIL_SPECIMEN"),
        coordinateUncertaintyInMeters = c(10, 10),
        stringsAsFactors = FALSE
      )
    )
  }
  resolucion <- list(
    checklistKey = peruocc:::gbif_col_xr_key,
    taxonKey = NULL,
    kingdomKey = "B",
    requested_name = "Plantae",
    accepted_name = "Plantae",
    matchType = "EXACT",
    rank = "KINGDOM"
  )

  resultado <- peruocc:::buscar_gbif_por_poligono(
    poligono_prueba_fuentes(),
    grupo = "flora",
    limite = 2,
    resolucion_taxonomica = resolucion,
    buscar_fun = buscar_falso,
    verbose = FALSE
  )

  expect_equal(nrow(resultado), 1)
  expect_identical(resultado$sourceRecordID, "uno")
  expect_identical(llamadas[[1]]$checklistKey, peruocc:::gbif_col_xr_key)
  expect_identical(llamadas[[1]]$kingdomKey, "B")
  expect_identical(llamadas[[1]]$hasGeospatialIssue, FALSE)
})

test_that("la consulta iNaturalist cuenta, filtra y estandariza observaciones", {
  consulta_falsa <- function(..., meta = FALSE) {
    if (isTRUE(meta)) {
      return(list(meta = list(found = 1L)))
    }
    data.frame(
      id = 123L,
      scientific_name = "Cantua buxifolia",
      latitude = -12.05,
      longitude = -77.05,
      observed_on = "2026-01-01",
      rank = "species",
      user_login = "observadora",
      positional_accuracy = 12,
      license = "cc-by",
      stringsAsFactors = FALSE
    )
  }

  resultado <- peruocc:::buscar_inat_por_poligono(
    poligono_prueba_fuentes(),
    grupo = "flora",
    limite = NULL,
    consulta_fun = consulta_falsa,
    verbose = FALSE
  )

  expect_equal(nrow(resultado), 1)
  expect_identical(resultado$scientificName, "Cantua buxifolia")
  expect_identical(resultado$kingdom, "Plantae")
  expect_identical(attr(resultado, "api_total"), 1L)
  expect_true(attr(resultado, "api_complete"))
})
