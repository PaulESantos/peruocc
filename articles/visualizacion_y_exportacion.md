# Visualización Cartográfica y Exportación de Ocurrencias

## Introducción

`peruocc` incluye utilidades especializadas para la representación
espacial de observaciones biológicas y la exportación estructurada de
resultados a formatos compatibles con sistemas de información geográfica
(SIG) y publicaciones científicas.

Por defecto, todas las funciones de búsqueda y graficado retornan
objetos en memoria (`data.frame`, `sf`, `ggplot`) sin escribir en disco,
siguiendo las mejores prácticas de R y las políticas de CRAN. Cuando el
usuario lo desee, los artefactos pueden ser exportados directamente o
mediante funciones dedicadas.

------------------------------------------------------------------------

## 1. Visualización Cartográfica con ggplot2

La función
[`graficar_ocurrencias()`](https://paulesantos.github.io/peruocc/reference/graficar_ocurrencias.md)
crea composiciones cartográficas limpias que combinan el polígono
administrativo oficial de fondo con las observaciones superpuestas.

### Clasificación por Repositorio de Origen (`source`)

Permite comparar visualmente el aporte relativo de **GBIF** frente a
**iNaturalist**:

``` r

library(peruocc)

# Realizar consulta en memoria (sin escribir en disco)
resultado <- buscar_especies_provincia(
  provincia = "Cusco",
  departamento = "Cusco",
  grupo = "flora",
  limite_por_api = 200
)

# Generar mapa en pantalla diferenciando proveedores de datos
mapa_fuente <- graficar_ocurrencias(
  resultado_lista = resultado,
  color_por = "source"
)

print(mapa_fuente)
```

### Clasificación por Reino Taxonómico (`kingdom`)

Permite visualizar la distribución espacial segregada por reino (por
ejemplo, *Plantae*, *Animalia*, *Fungi*):

``` r

# Generar mapa diferenciando reinos biológicos
mapa_reino <- graficar_ocurrencias(
  resultado_lista = resultado,
  color_por = "kingdom"
)

print(mapa_reino)
```

Si deseas exportar el gráfico a disco a 300 DPI, activa
`guardar_mapa = TRUE`:

``` r

mapa_exportado <- graficar_ocurrencias(
  resultado_lista = resultado,
  color_por = "source",
  guardar_mapa = TRUE
)
```

------------------------------------------------------------------------

## 2. Exportación de Resultados y Artefactos

Existen dos maneras de guardar los resultados en disco:

### Opción A: Función dedicada `exportar_resultados()` (Recomendado)

Permite inspeccionar los datos primero y exportar selectivamente:

``` r

# Exportar todos los formatos (CSV, GeoJSON y Manifiesto JSON)
archivos <- exportar_resultados(resultado)

# O exportar únicamente CSV y GeoJSON a un directorio personalizado:
exportar_resultados(
  resultado = resultado,
  dir_salida = "mis_resultados",
  formatos = c("csv", "geojson")
)
```

### Opción B: Parámetro directo `guardar_resultados = TRUE`

``` r

resultado <- buscar_especies_distrito(
  distrito = "Miraflores",
  departamento = "Lima",
  guardar_resultados = TRUE
)
```

------------------------------------------------------------------------

## 3. Estructura de Artefactos Generados

1.  **`processed/ocurrencias_*.csv`**:
    - Tabla con todos los registros y atributos Darwin Core
      estandarizados.
2.  **`processed/ocurrencias_*.geojson`**:
    - Capa espacial vectorial de puntos para importar directamente en
      **QGIS**, **ArcGIS** o visores web como **Leaflet** / **Mapbox**.
3.  **`processed/manifiesto_*.json`**:
    - Archivo de metadatos con la información completa de
      reproducibilidad: versión de R, versiones de paquetes de
      dependencias (`sf`, `rgbif`, `rinat`), coordenadas WKT del
      polígono y parámetros utilizados.
4.  **`results/mapa_*.png`**:
    - Mapa cartográfico en alta resolución exportado a 300 DPI listo
      para reportes e informes.

------------------------------------------------------------------------

## 4. Integración con SIG (QGIS / R Spatial)

Para cargar la capa espacial generada en scripts posteriores o flujos de
modelado de nicho ecológico (SDM):

``` r

library(sf)

# Leer archivo GeoJSON exportado por peruocc
capa_ocurrencias <- sf::st_read("peruocc/processed/ocurrencias_distrito_miraflores_biodiversidad.geojson")

# Inspección de geometría y tabla de atributos
print(capa_ocurrencias)
```
