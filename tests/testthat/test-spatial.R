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
