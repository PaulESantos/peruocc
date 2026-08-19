test_that("la normalizacion de texto es consistente", {
  expect_identical(peruocc:::normalizar_texto("Junin"), "JUNIN")
  expect_identical(peruocc:::normalizar_texto("Madre de Dios"), "MADRE DE DIOS")
})

test_that("la validacion acepta descarga completa y niveles", {
  expect_invisible(peruocc:::validar_entrada_busqueda("Lima", NULL, NULL, nivel = "distrito"))
  expect_invisible(peruocc:::validar_entrada_busqueda("Cusco", "fauna", 100, nivel = "provincia"))
  expect_error(peruocc:::validar_entrada_busqueda("", NULL, 10))
  expect_error(peruocc:::validar_entrada_busqueda("Lima", "hongos", 10))
})

test_that("el esquema de ocurrencias es estable", {
  esquema <- peruocc:::schema_ocurrencias()
  expect_true(all(c("occurrenceID", "sourceRecordID", "sourceURL", "district", "province", "department", "source", "scientificName") %in% names(esquema)))
})
