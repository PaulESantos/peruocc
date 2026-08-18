# Pruebas sin red: ejecutar con Rscript tests/run_tests.R desde la raíz.
source("R/project_utils.R")
source("R/spatial_utils.R")

stopifnot(normalizar_texto("Madre de Dios") == "MADRE DE DIOS")
stopifnot(normalizar_texto("Junín") == "JUNIN")
stopifnot(identical(names(schema_ocurrencias()), c("occurrenceID", "sourceRecordID", "sourceURL", "datasetKey", "license", "basisOfRecord", "scientificName", "decimalLatitude", "decimalLongitude", "eventDate", "taxonRank", "kingdom", "phylum", "class", "order", "family", "genus", "species", "recordedBy", "coordinateUncertaintyInMeters", "source", "district")))
stopifnot(inherits(try(validar_entrada_busqueda("", NULL, 10), silent = TRUE), "try-error"))
stopifnot(inherits(try(validar_entrada_busqueda("Lima", "hongos", 10), silent = TRUE), "try-error"))
stopifnot(inherits(try(validar_entrada_busqueda("Lima", NULL, 10.5), silent = TRUE), "try-error"))
stopifnot(isTRUE(validar_entrada_busqueda("Lima", NULL, NULL)))
cat("OK: pruebas unitarias básicas superadas.\n")
