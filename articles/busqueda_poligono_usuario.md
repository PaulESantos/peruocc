# Búsqueda de Ocurrencias con Polígonos Personalizados (Shapefile, GeoJSON y sf)

## Introducción

Además de realizar consultas sobre las delimitaciones
político-administrativas oficiales del Perú (distritos y provincias),
`peruocc` ofrece la función
[`buscar_especies_poligono()`](https://paulesantos.github.io/peruocc/reference/buscar_especies_poligono.md).

Esta utilidad permite delimitar áreas de estudio independientes, tales
como: \* Polígonos de muestreo de campo y cuadrantes de inventario. \*
Áreas Naturales Protegidas (ANP), concesiones forestales o zonas de
amortiguamiento. \* Áreas de influencia directa/indirecta (buffers) de
proyectos ambientales. \* Archivos espaciales en formatos estándar
(`.shp`, `.geojson`, `.gpkg`, `.kml`).

------------------------------------------------------------------------

## 1. Carga de Librerías y Configuración

Cargamos `peruocc` y `sf` para el manejo de geometrías vectoriales:

``` r

library(peruocc)
#> ── Cargando peruocc ────────────────────────────────────────────────── v0.1.0 ──
#> ✔ geoperu 0.0.1   • Límites cartográficos oficiales del Perú
#> ✔ rgbif   3.8.5   • Extracción de ocurrencias desde GBIF
#> ✔ rinat   0.1.10  • Observaciones ciudadanas de iNaturalist
#> ✔ sf      1.1.2   • Operaciones geométricas y filtros espaciales
library(sf)
library(ggplot2)

# Configurar el directorio de trabajo para artefactos y caché
peruocc_data_dir("peruocc-output")
```

------------------------------------------------------------------------

## 2. Creación de un Polígono de Estudio Personalizado

Podemos definir cualquier geometría poligonal en R. En este ejemplo,
creamos un polígono rectangular de interés biológico en la costa central
del Perú (alrededor de los humedales y costa de Lima):

``` r

# Coordenadas de los vértices del polígono (WGS84: Longitud, Latitud)
coordenadas <- matrix(
  c(
    -77.04, -12.06,
    -77.00, -12.06,
    -77.00, -12.02,
    -77.04, -12.02,
    -77.04, -12.06
  ),
  ncol = 2,
  byrow = TRUE
)

# Construir el objeto sf con proyección geográfica EPSG:4326 (WGS84)
mi_zona_estudio <- sf::st_as_sf(
  sf::st_sfc(sf::st_polygon(list(coordenadas)), crs = 4326)
)

print(mi_zona_estudio)
#> Simple feature collection with 1 feature and 0 fields
#> Geometry type: POLYGON
#> Dimension:     XY
#> Bounding box:  xmin: -77.04 ymin: -12.06 xmax: -77 ymax: -12.02
#> Geodetic CRS:  WGS 84
#>                                x
#> 1 POLYGON ((-77.04 -12.06, -7...
```

------------------------------------------------------------------------

## 3. Consulta Integrada de Biodiversidad: `buscar_especies_poligono()`

Ejecutamos la búsqueda de flora dentro del polígono creado. `peruocc`
gestiona automáticamente: 1. La consulta síncrona a **GBIF** con
simplificación adaptativa WKT en UTM. 2. La consulta a **iNaturalist**
por Bounding Box. 3. El **recorte espacial exacto en memoria
([`sf::st_intersects`](https://r-spatial.github.io/sf/reference/geos_binary_pred.html))**
para asegurar que cada punto caiga estrictamente dentro de la geometría.
4. La estandarización y deduplicación bajo el estándar **Darwin Core**.

``` r

resultado_personalizado <- buscar_especies_poligono(
  poligono = mi_zona_estudio,
  nombre = "Area_Estudio_Costa",
  grupo = "flora",
  limite_por_api = 25
)
#> 
#> ── Búsqueda Integrada en Polígono: AREA_ESTUDIO_COSTA ──────────────────────────
#> • Grupo: flora
#> ℹ [GBIF] Iniciando búsqueda de ocurrencias...
#> ℹ [GBIF] Filtrando por reino Plantae (Flora).
#> ℹ [GBIF] Consultando registros dentro del polígono de Unidad seleccionada (límite: "25")...
#> ✔ [GBIF] Búsqueda finalizada. Se filtraron 25 registro(s) que caen dentro del polígono seleccionado.
#> ℹ [iNaturalist] Iniciando búsqueda de ocurrencias...
#> ℹ [iNaturalist] Filtrando por reino Plantae (Flora).
#> ℹ [iNaturalist] Consultando registros dentro de la caja delimitadora de Unidad seleccionada (límite: "25")...
#> ℹ [iNaturalist] Se descargaron 25 registros en la caja delimitadora. Aplicando filtro espacial...
#> ✔ [iNaturalist] Búsqueda finalizada. 25 de 25 registros caen dentro del polígono seleccionado.
#> ✔ Consolidación exitosa. Total de registros unificados: 50
#> 
#> ── Resumen de Registros ──
#> 
#> • GBIF: 25 registro(s)
#> • iNaturalist: 25 registro(s)
#> ✔ Total consolidado: 50 registro(s)
```

------------------------------------------------------------------------

## 4. Inspección de los Resultados Obtenidos

El objeto devuelto contiene la estructura estándar de `peruocc`:

``` r

# Resumen de registros por base de datos
print(resultado_personalizado$resumen)
#> $nivel
#> [1] "poligono"
#> 
#> $unidad
#> [1] "Area_Estudio_Costa"
#> 
#> $distrito
#> [1] NA
#> 
#> $provincia
#> [1] NA
#> 
#> $departamento
#> [1] NA
#> 
#> $total_registros
#> [1] 50
#> 
#> $registros_gbif
#> [1] 25
#> 
#> $registros_inat
#> [1] 25
#> 
#> $limite_por_api
#> [1] 25
#> 
#> $gbif_total_reportado_api
#> [1] NA
#> 
#> $inat_total_reportado_api
#> [1] NA
#> 
#> $gbif_descarga_completa_api
#> [1] FALSE
#> 
#> $inat_descarga_completa_api
#> [1] FALSE
#> 
#> $lotes_espaciales
#> [1] 1
#> 
#> $fallos_lotes
#> character(0)
#> 
#> $nota_cobertura
#> [1] "Se solicito una muestra limitada por API; la cobertura puede estar truncada."

# Vista previa de las primeras ocurrencias
head(resultado_personalizado$ocurrencias[, c("scientificName", "source", "eventDate", "decimalLatitude", "decimalLongitude")])
#> # A tibble: 6 × 5
#>   scientificName source   eventDate decimalLatitude decimalLongitude
#>   <chr>          <chr>    <chr>               <dbl>            <dbl>
#> 1 Washingtonia … GBIF     2026-04-…           -12.1            -77.0
#> 2 Fragaria vesc… GBIF     2025-05-…           -12.0            -77.0
#> 3 Annona cherim… GBIF     2025-05-…           -12.0            -77.0
#> 4 Passiflora ed… GBIF     2025-06-…           -12.0            -77.0
#> 5 Urtica urens … GBIF     2025-08-…           -12.1            -77.0
#> 6 Sonchus asper… GBIF     2025-10-…           -12.1            -77.0
```

------------------------------------------------------------------------

## 5. Visualización Cartográfica con `graficar_ocurrencias()`

Podemos generar composiciones en `ggplot2` superponiendo el polígono con
las observaciones:

### A. Clasificación por Proveedor de Datos (GBIF vs iNaturalist)

``` r

mapa_fuentes <- graficar_ocurrencias(
  resultado_lista = resultado_personalizado,
  color_por = "source"
)

print(mapa_fuentes)
```

![](busqueda_poligono_usuario_files/figure-html/mapa_fuente-1.png)

### B. Clasificación por Reino Taxonómico

``` r

mapa_reinos <- graficar_ocurrencias(
  resultado_lista = resultado_personalizado,
  color_por = "kingdom"
)

print(mapa_reinos)
```

![](busqueda_poligono_usuario_files/figure-html/mapa_reino-1.png)

------------------------------------------------------------------------

## 6. Consulta desde un Archivo en Disco (Shapefile / GeoJSON)

[`buscar_especies_poligono()`](https://paulesantos.github.io/peruocc/reference/buscar_especies_poligono.md)
también acepta directamente una ruta a un archivo espacial en disco
(`.shp`, `.geojson`, `.gpkg` o `.kml`).

Para demostrarlo, guardamos el polígono en un archivo `.geojson` y
ejecutamos la consulta directamente desde la ruta:

``` r

# 1. Guardar el polígono temporalmente como archivo GeoJSON
ruta_capa <- file.path(tempdir(), "mi_reserva.geojson")
sf::st_write(mi_zona_estudio, ruta_capa, quiet = TRUE, delete_dsn = TRUE)

# 2. Consultar directamente pasando la ruta del archivo
resultado_desde_archivo <- buscar_especies_poligono(
  poligono = ruta_capa,
  nombre = "Reserva_Local",
  grupo = "flora",
  limite_por_api = 15
)
#> 
#> ── Búsqueda Integrada en Polígono: RESERVA_LOCAL ───────────────────────────────
#> • Grupo: flora
#> ℹ [GBIF] Iniciando búsqueda de ocurrencias...
#> ℹ [GBIF] Filtrando por reino Plantae (Flora).
#> ℹ [GBIF] Consultando registros dentro del polígono de Unidad seleccionada (límite: "15")...
#> ✔ [GBIF] Búsqueda finalizada. Se filtraron 15 registro(s) que caen dentro del polígono seleccionado.
#> ℹ [iNaturalist] Iniciando búsqueda de ocurrencias...
#> ℹ [iNaturalist] Filtrando por reino Plantae (Flora).
#> ℹ [iNaturalist] Consultando registros dentro de la caja delimitadora de Unidad seleccionada (límite: "15")...
#> ℹ [iNaturalist] Se descargaron 15 registros en la caja delimitadora. Aplicando filtro espacial...
#> ✔ [iNaturalist] Búsqueda finalizada. 15 de 15 registros caen dentro del polígono seleccionado.
#> ✔ Consolidación exitosa. Total de registros unificados: 30
#> 
#> ── Resumen de Registros ──
#> 
#> • GBIF: 15 registro(s)
#> • iNaturalist: 15 registro(s)
#> ✔ Total consolidado: 30 registro(s)

# 3. Exportar resultados con manifiesto de reproducibilidad
exportar_resultados(resultado_desde_archivo)
#> ✔ Registros tabulares guardados en: /home/runner/work/peruocc/peruocc/vignettes/peruocc-output/processed/ocurrencias_20260823T035647Z_poligono_reservalocal_flora.csv
#> ✔ Capa espacial GeoJSON guardada en: /home/runner/work/peruocc/peruocc/vignettes/peruocc-output/processed/ocurrencias_20260823T035647Z_poligono_reservalocal_flora.geojson
#> ✔ Manifiesto JSON guardado en: /home/runner/work/peruocc/peruocc/vignettes/peruocc-output/processed/manifiesto_20260823T035647Z_poligono_reservalocal_flora.json
```

------------------------------------------------------------------------

## Conclusión

La función
[`buscar_especies_poligono()`](https://paulesantos.github.io/peruocc/reference/buscar_especies_poligono.md)
extiende la versatilidad de `peruocc`, permitiendo integrar inventarios
biológicos y análisis de biodiversidad sobre cualquier área geográfica
en el Perú sin depender exclusivamente de límites políticos distritales
o provinciales.
