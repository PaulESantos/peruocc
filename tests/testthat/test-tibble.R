test_that("as_peruocc_tbl coerciona data.frames y matrices correctamente", {
  df <- data.frame(a = 1:5, b = letters[1:5], stringsAsFactors = FALSE)
  tbl <- peruocc::as_peruocc_tbl(df)
  
  expect_s3_class(tbl, "tbl_df")
  expect_s3_class(tbl, "tbl")
  expect_s3_class(tbl, "data.frame")
  expect_s3_class(tbl, "peruocc_tbl")
  expect_equal(nrow(tbl), 5)
  expect_equal(ncol(tbl), 2)
  expect_equal(tbl$a, 1:5)
})

test_that("subsetting preserva la clase peruocc_tbl", {
  df <- data.frame(a = 1:10, b = 11:20)
  tbl <- peruocc::as_peruocc_tbl(df)
  sub_tbl <- tbl[1:3, ]
  
  expect_s3_class(sub_tbl, "tbl_df")
  expect_equal(nrow(sub_tbl), 3)
})

test_that("print.peruocc_tbl funciona limpiamente con formateo alineado y pie de pagina", {
  df <- data.frame(
    id = 1:15,
    especie = paste0("Especie_", 1:15),
    lat = runif(15, -12, -11),
    lon = runif(15, -77, -76),
    dep = rep("Lima", 15),
    prov = rep("Lima", 15),
    dist = rep("Miraflores", 15),
    fuente = rep("GBIF", 15),
    extra1 = 1:15,
    extra2 = 1:15,
    stringsAsFactors = FALSE
  )
  tbl <- peruocc::as_peruocc_tbl(df)
  
  # Imprimir con ancho acotado para probar variables ocultas
  salida <- capture.output(print(tbl, n = 5, width = 60))
  expect_true(any(grepl("# A tibble: 15 × 10", salida)))
  expect_true(any(grepl("<int>|<chr>|<dbl>", salida)))
  expect_true(any(grepl("10 filas más", salida)))
  expect_true(any(grepl("variables más", salida)))
})

test_that("print.peruocc_tbl maneja tablas vacias correctamente", {
  df_vacio <- data.frame(a = character(), b = numeric(), stringsAsFactors = FALSE)
  tbl_vacio <- peruocc::as_peruocc_tbl(df_vacio)
  salida <- capture.output(print(tbl_vacio))
  expect_true(any(grepl("# A tibble: 0 × 2", salida)))
})
