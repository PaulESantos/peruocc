test_that("la normalizacion de texto es consistente", {
  expect_identical(peruocc:::normalizar_texto("Junin"), "JUNIN")
  expect_identical(peruocc:::normalizar_texto("Madre de Dios"), "MADRE DE DIOS")
})

test_that("la validacion acepta descarga completa y niveles", {
  expect_invisible(peruocc:::validar_entrada_busqueda("Lima", NULL, NULL, nivel = "distrito"))
  expect_invisible(peruocc:::validar_entrada_busqueda("Cusco", "fauna", 100, nivel = "provincia"))
  expect_invisible(peruocc:::validar_entrada_busqueda("Mi_Poligono", "flora", 50, nivel = "poligono"))
  expect_error(peruocc:::validar_entrada_busqueda("", NULL, 10))
  expect_error(peruocc:::validar_entrada_busqueda("Lima", "hongos", 10))
})

test_that("el esquema de ocurrencias es estable", {
  esquema <- peruocc:::schema_ocurrencias()
  expect_true(all(c("occurrenceID", "sourceRecordID", "sourceURL", "district", "province", "department", "source", "scientificName") %in% names(esquema)))
})

test_that("exportar_resultados valida estructura y maneja vacios", {
  expect_error(peruocc::exportar_resultados(NULL))
  expect_error(peruocc::exportar_resultados("no_es_lista"))
  
  res_vacio <- list(
    unidad_sf = NULL,
    ocurrencias = data.frame(),
    resumen = list(unidad = "Test"),
    parametros = list(nivel = "distrito")
  )
  expect_invisible(peruocc::exportar_resultados(res_vacio))
})

test_that("peruocc_data_dir y rutas no crean archivos por defecto", {
  op_orig <- getOption("peruocc.data_dir")
  on.exit(options(peruocc.data_dir = op_orig), add = TRUE)
  
  options(peruocc.data_dir = NULL)
  expect_null(peruocc::peruocc_data_dir())
  expect_null(peruocc:::ruta_cache())
  expect_null(peruocc:::ruta_peruocc())
  
  # Al configurar una ruta valida, la retorna y la crea
  tmp <- file.path(tempdir(), "test_config_dir")
  expect_identical(peruocc::peruocc_data_dir(tmp), normalizePath(tmp, winslash = "/", mustWork = FALSE))
  expect_true(dir.exists(tmp))
  expect_true(grepl("cache", peruocc:::ruta_cache()))
})

test_that("verificar_y_configurar_entorno funciona correctamente", {
  expect_true(peruocc::verificar_y_configurar_entorno())
})
