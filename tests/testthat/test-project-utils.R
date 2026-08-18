test_that("la normalización de texto es consistente", {
  expect_identical(peruspecies:::normalizar_texto("Junín"), "JUNIN")
  expect_identical(peruspecies:::normalizar_texto("Madre de Dios"), "MADRE DE DIOS")
})

test_that("la validación acepta descarga completa", {
  expect_invisible(peruspecies:::validar_entrada_busqueda("Lima", NULL, NULL))
  expect_error(peruspecies:::validar_entrada_busqueda("", NULL, 10))
  expect_error(peruspecies:::validar_entrada_busqueda("Lima", "hongos", 10))
})

test_that("el esquema de ocurrencias es estable", {
  esquema <- peruspecies:::schema_ocurrencias()
  expect_true(all(c("occurrenceID", "sourceRecordID", "sourceURL", "district") %in% names(esquema)))
})
