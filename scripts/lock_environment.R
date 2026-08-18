# Ejecutar una vez en un entorno validado para crear/actualizar el lockfile.
if (!requireNamespace("renv", quietly = TRUE)) install.packages("renv", repos = "https://cloud.r-project.org")
renv::init(bare = TRUE)
renv::install(c("sf", "rgbif", "rinat", "ggplot2", "dplyr", "readr", "jsonlite", "geoperu"))
renv::snapshot(prompt = FALSE)
