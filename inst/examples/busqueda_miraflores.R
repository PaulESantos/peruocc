# Ejecutar después de instalar o cargar peruspecies.
peruspecies::peruspecies_data_dir("peruspecies-output")

resultado <- peruspecies::buscar_especies_distrito(
  distrito = "Miraflores",
  departamento = "Lima",
  provincia = "Lima",
  grupo = "flora",
  limite_por_api = 100,
  guardar_resultados = TRUE
)

peruspecies::graficar_ocurrencias(resultado, guardar_mapa = TRUE)
