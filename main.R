# main.R
# Script principal para ejecutar el proyecto de ocurrencias de biodiversidad en distritos de Perú.

# 1. Configurar y verificar el entorno (Instalación de paquetes si es necesario)
source("R/setup.R")
verificar_y_configurar_entorno()

# Cargar las librerías necesarias
library(sf)
library(ggplot2)
library(dplyr)

# 2. Cargar módulos del proyecto
source("R/spatial_utils.R")
source("R/project_utils.R")
source("R/query_gbif.R")
source("R/query_inat.R")
source("R/query_combined.R")
source("R/visualize.R")

cat("\n=====================================================================\n")
cat("INICIANDO FLUJO DE TRABAJO DE PRUEBA EN R\n")
cat("=====================================================================\n\n")

# --- CASO DE ESTUDIO 1: Miraflores (Lima) ---
# Miraflores es un distrito urbano costero con abundantes observaciones domésticas y ornamentales.
cat(">>> Ejecutando Caso 1: Buscar flora (plantas) en el distrito de Miraflores (Lima) <<<\n")
res_miraflores <- tryCatch({
  buscar_especies_distrito(
    distrito = "Miraflores",
    departamento = "Lima",
    provincia = "Lima",
    grupo = "flora",
    limite_por_api = 100,
    guardar_resultados = TRUE
  )
}, error = function(e) {
  cat("[Error en Caso 1]: ", e$message, "\n")
  return(NULL)
})

if (!is.null(res_miraflores) && nrow(res_miraflores$ocurrencias) > 0) {
  # Graficar clasificado por base de datos (fuente)
  mapa_miraflores_source <- graficar_ocurrencias(res_miraflores, color_por = "source", guardar_mapa = TRUE)
}


# --- CASO DE ESTUDIO 2: Tambopata (Madre de Dios) ---
# Tambopata es uno de los distritos de selva tropical con mayor biodiversidad en el mundo.
cat("\n>>> Ejecutando Caso 2: Buscar fauna (animales) en Tambopata (Madre de Dios) <<<\n")
res_tambopata <- tryCatch({
  buscar_especies_distrito(
    distrito = "Tambopata",
    departamento = "Madre de Dios",
    grupo = "fauna",
    limite_por_api = 150,
    guardar_resultados = TRUE,
    tolerancia_simplificacion = 200 # Simplificar un poco más el polígono para GBIF (200m) ya que es un distrito extenso
  )
}, error = function(e) {
  cat("[Error en Caso 2]: ", e$message, "\n")
  return(NULL)
})

if (!is.null(res_tambopata) && nrow(res_tambopata$ocurrencias) > 0) {
  # Graficar clasificado por base de datos
  mapa_tambopata_source <- graficar_ocurrencias(res_tambopata, color_por = "source", guardar_mapa = TRUE)
}


# --- CASO DE ESTUDIO 3: Buscar una especie específica ---
# Por ejemplo, la Cantuta (Flor nacional del Perú - Cantua buxifolia) en el distrito de Tarma (Junín)
cat("\n>>> Ejecutando Caso 3: Buscar especie específica (Cantua buxifolia) en Tarma (Junín) <<<\n")
res_cantuta <- tryCatch({
  buscar_especies_distrito(
    distrito = "Tarma",
    departamento = "Junin",
    nombre_cientifico = "Cantua buxifolia",
    limite_por_api = 50,
    guardar_resultados = TRUE
  )
}, error = function(e) {
  cat("[Error en Caso 3]: ", e$message, "\n")
  return(NULL)
})

if (!is.null(res_cantuta) && nrow(res_cantuta$ocurrencias) > 0) {
  # Graficar clasificado por base de datos
  mapa_cantuta <- graficar_ocurrencias(res_cantuta, color_por = "source", guardar_mapa = TRUE)
}

cat("\n=====================================================================\n")
cat("PROCESO DE PRUEBA COMPLETADO CON ÉXITO\n")
cat("Verifique 'data/processed/' y 'results/' para los datos, manifiestos y mapas generados.\n")
cat("=====================================================================\n")
