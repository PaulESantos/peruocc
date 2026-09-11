# Ejemplo de uso de peruocc utilizando un directorio temporal.
dir_salida <- file.path(tempdir(), "peruocc-ejemplo")
peruocc::peruocc_data_dir(dir_salida)

# 1. Busqueda a nivel de distrito
resultado_distrito <- peruocc::buscar_especies_distrito(
  distrito = "Miraflores",
  departamento = "Lima",
  provincia = "Lima",
  grupo = "flora",
  limite_por_api = 100
)

peruocc::exportar_resultados(resultado_distrito, dir_salida = dir_salida)
peruocc::graficar_ocurrencias(resultado_distrito, guardar_mapa = TRUE, ruta_salida = file.path(dir_salida, "mapa_distrito.png"))

# 2. Busqueda a nivel de provincia
resultado_provincia <- peruocc::buscar_especies_provincia(
  provincia = "Cusco",
  departamento = "Cusco",
  grupo = "fauna",
  limite_por_api = 100
)

peruocc::exportar_resultados(resultado_provincia, dir_salida = dir_salida)
peruocc::graficar_ocurrencias(resultado_provincia, guardar_mapa = TRUE, ruta_salida = file.path(dir_salida, "mapa_provincia.png"))
