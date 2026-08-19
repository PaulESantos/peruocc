# Ejecutar despues de instalar o cargar peruocc.
peruocc::peruocc_data_dir("peruocc-output")

# 1. Busqueda a nivel de distrito
resultado_distrito <- peruocc::buscar_especies_distrito(
  distrito = "Miraflores",
  departamento = "Lima",
  provincia = "Lima",
  grupo = "flora",
  limite_por_api = 100,
  guardar_resultados = TRUE
)

peruocc::graficar_ocurrencias(resultado_distrito, guardar_mapa = TRUE)

# 2. Busqueda a nivel de provincia
resultado_provincia <- peruocc::buscar_especies_provincia(
  provincia = "Cusco",
  departamento = "Cusco",
  grupo = "fauna",
  limite_por_api = 100,
  guardar_resultados = TRUE
)

peruocc::graficar_ocurrencias(resultado_provincia, guardar_mapa = TRUE)
