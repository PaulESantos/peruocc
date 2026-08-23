test_that("preparar_poligono_usuario valida y procesa objetos sf correctamente", {
  # Crear un poligono sf sintetico en WGS84
  coords <- matrix(c(
    -77.05, -12.10,
    -77.01, -12.10,
    -77.01, -12.05,
    -77.05, -12.05,
    -77.05, -12.10
  ), ncol = 2, byrow = TRUE)
  
  poly <- sf::st_polygon(list(coords))
  sf_poly <- sf::st_as_sf(sf::st_sfc(poly, crs = 4326))
  
  res <- peruocc::preparar_poligono_usuario(sf_poly, nombre = "Zona_Test")
  
  expect_s3_class(res, "sf")
  expect_equal(res$unidad, "Zona_Test")
  expect_equal(sf::st_crs(res)$epsg, 4326)
  expect_equal(nrow(res), 1)
})

test_that("preparar_poligono_usuario gestiona errores de entrada", {
  expect_error(peruocc::preparar_poligono_usuario(NULL))
  expect_error(peruocc::preparar_poligono_usuario("ruta/que/no/existe.shp"))
  expect_error(peruocc::preparar_poligono_usuario(12345))
})

test_that("dividir_poligono_por_area crea teselas y conserva atributos", {
  coords <- matrix(c(
    -77.00, -12.00,
    -76.80, -12.00,
    -76.80, -11.80,
    -77.00, -11.80,
    -77.00, -12.00
  ), ncol = 2, byrow = TRUE)
  poly <- sf::st_as_sf(sf::st_sfc(sf::st_polygon(list(coords)), crs = 4326))
  poly$departamento <- "Lima"
  poly$provincia <- "Lima"
  poly$distrito <- "Prueba"

  teselas <- peruocc:::dividir_poligono_por_area(poly, max_area_ha = 1000)

  expect_gt(nrow(teselas), 1)
  expect_equal(teselas$tile_id, seq_len(nrow(teselas)))
  expect_true(all(teselas$distrito == "Prueba"))
  expect_error(peruocc:::dividir_poligono_por_area(poly, max_area_ha = 0))
  
  # Macro-bloques adaptativos con max_lotes
  teselas_acotadas <- peruocc:::dividir_poligono_por_area(poly, max_area_ha = 500, max_lotes = 4)
  expect_lte(nrow(teselas_acotadas), 9) # grilla 2x2 o 3x3 acotada
})

test_that("preparar_lotes_espaciales aplica modo auto y segmentada adaptativa", {
  coords <- matrix(c(
    -77.00, -12.00,
    -76.80, -12.00,
    -76.80, -11.80,
    -77.00, -11.80,
    -77.00, -12.00
  ), ncol = 2, byrow = TRUE)
  poly <- sf::st_as_sf(sf::st_sfc(sf::st_polygon(list(coords)), crs = 4326))
  poly$distrito <- "Gran_Distrito"
  
  # Busqueda con especie: 1 lote directo
  lotes_sp <- peruocc:::preparar_lotes_espaciales(
    poly, nivel = "distrito", nombre = "Gran_Distrito", departamento = "Lima",
    estrategia_espacial = "auto", nombre_cientifico = "Panthera onca"
  )
  expect_equal(nrow(lotes_sp), 1)
  
  # Busqueda general sin especie en area grande: macro-bloques adaptativos
  lotes_gen <- peruocc:::preparar_lotes_espaciales(
    poly, nivel = "distrito", nombre = "Gran_Distrito", departamento = "Lima",
    estrategia_espacial = "auto", nombre_cientifico = NULL, max_lotes = 6
  )
  expect_gte(nrow(lotes_gen), 1)
  expect_lte(nrow(lotes_gen), 12)
})
