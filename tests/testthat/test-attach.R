test_that("helpers de version y formateo de arranque funcionan", {
  ver_hl <- peruocc:::highlight_version("0.1.0")
  expect_equal(ver_hl, "0.1.0")
  
  ver_dev <- peruocc:::highlight_version("0.1.0.9000")
  expect_true(nzchar(ver_dev))
  
  msg <- peruocc:::peruocc_attach_message(c("sf", "rgbif"))
  expect_true(grepl("Cargando peruocc", msg))
  expect_true(grepl("sf", msg))
  expect_true(grepl("rgbif", msg))
})

test_that("is_attached y core_unloaded devuelven valores correctos", {
  expect_true(is.logical(peruocc:::is_attached("base")))
  expect_true(peruocc:::is_attached("base"))
  expect_false(peruocc:::is_attached("paquete_inexistente_xyz_123"))
  
  no_cargados <- peruocc:::core_unloaded()
  expect_true(is.character(no_cargados))
})
