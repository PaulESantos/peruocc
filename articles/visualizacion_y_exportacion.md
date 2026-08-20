# Configuración, Exportación y Visualización de Resultados

## Introducción

El paquete `peruocc` está diseñado tanto para la exploración interactiva
y rápida de ocurrencias de biodiversidad en memoria, como para flujos de
trabajo reproducibles en producción y análisis espacial (SIG).

Esta guía explica: 1. Cómo configurar el directorio de almacenamiento y
caché
([`peruocc_data_dir()`](https://paulesantos.github.io/peruocc/reference/peruocc_data_dir.md)).
2. La diferencia entre consultas interactivas en memoria
(`guardar_resultados = FALSE`) y persistencia en disco
(`guardar_resultados = TRUE`). 3. La función dedicada
[`exportar_resultados()`](https://paulesantos.github.io/peruocc/reference/exportar_resultados.md)
y los formatos generados (CSV, GeoJSON y Manifiesto de
reproducibilidad). 4. La visualización cartográfica con
[`graficar_ocurrencias()`](https://paulesantos.github.io/peruocc/reference/graficar_ocurrencias.md).

------------------------------------------------------------------------

## 1. Configuración del Directorio de Trabajo: `peruocc_data_dir()`

La función
[`peruocc_data_dir()`](https://paulesantos.github.io/peruocc/reference/peruocc_data_dir.md)
centraliza la ubicación en el disco donde se almacenarán tanto las capas
espaciales descargadas en caché como los resultados exportados.

``` r

library(peruocc)

# Configurar el directorio raíz del proyecto para artefactos
peruocc_data_dir("peruocc-output")
```

### ¿Por qué es útil y cómo funciona?

- **Control y Orden del Proyecto**: Mantiene todas las salidas y capas
  auxiliares organizadas en una única carpeta (por ejemplo,
  `./peruocc-output/`) en lugar de dispersarlas en la raíz de trabajo.
- **Caché Inteligente de Geometrías**: Al descargar límites distritales
  o departamentales oficiales (vía `geoperu`), el paquete guarda copias
  `.rds` en `peruocc-output/cache/`. Las siguientes consultas a esa
  misma zona cargarán la geometría instantáneamente sin volver a
  descargarla de internet.
- **Configuración Global Transparente**: Al ejecutar
  `peruocc_data_dir("peruocc-output")`, la ruta se guarda en las
  opciones de R (`options(peruocc.data_dir = ...)`). Todas las demás
  funciones del paquete sabrán automáticamente dónde leer y escribir.

### ¿Qué ocurre si NO ejecuto `peruocc_data_dir()`?

**No habrá ningún error y las consultas funcionarán con normalidad.** \*
**Caché**: `peruocc` recurrirá de forma transparente al directorio
estándar de caché del sistema operativo
(`tools::R_user_dir("peruocc", which = "cache")`). \* **Exportaciones**:
Si decides exportar archivos más adelante, se creará por defecto la
carpeta `./peruocc/processed/` en tu directorio de trabajo.

------------------------------------------------------------------------

## 2. Ejecución en Memoria vs. Guardado en Disco (`guardar_resultados`)

Todas las funciones principales de búsqueda
([`buscar_especies_distrito()`](https://paulesantos.github.io/peruocc/reference/buscar_especies_distrito.md),
[`buscar_especies_provincia()`](https://paulesantos.github.io/peruocc/reference/buscar_especies_provincia.md),
[`buscar_especies_peru()`](https://paulesantos.github.io/peruocc/reference/buscar_especies_peru.md))
incluyen el argumento `guardar_resultados`.

``` r

# Firma de la función
buscar_especies_distrito(
  distrito,
  departamento = NULL,
  provincia = NULL,
  ...,
  guardar_resultados = FALSE  # <- FALSE por defecto
)
```

### Comparativa: Consultas Experimentales vs. Guardado Automático

| Característica | `guardar_resultados = FALSE` (Por defecto / Experimental) | `guardar_resultados = TRUE` (Guardado Automático) |
|:---|:---|:---|
| **Destino de datos** | Solo memoria RAM en la sesión de R. | Memoria RAM + archivos guardados en disco. |
| **Velocidad de ejecución** | **Más rápida.** Evita la sobrecarga de I/O y serialización espacial. | Requiere tiempo adicional para escribir CSV, GeoJSON y JSON. |
| **Archivos generados** | Ninguno. | `.csv`, `.geojson` y `manifiesto_*.json` en la subcarpeta `processed/`. |
| **Casos de uso** | Análisis exploratorio, filtrado rápido, visualización interactiva y pruebas de parámetros. | Pipelines automatizados, ejecuciones desatendidas o procesamiento en lotes (*batch*). |

### Flujo de Trabajo Recomendado

Para la mayoría de los análisis, la mejor práctica es **trabajar primero
en memoria** y luego exportar selectivamente cuando los datos estén
listos:

``` r

# Paso 1: Consulta rápida en memoria (experimental / interactiva)
resultado <- buscar_especies_distrito(
  distrito = "Miraflores",
  departamento = "Lima",
  provincia = "Lima",
  grupo = "flora",
  limite_por_api = 150
)

# Paso 2: Inspeccionar resultados o graficar
summary(resultado$ocurrencias)

# Paso 3: Si los datos son conformes, exportar a disco
exportar_resultados(resultado)
```

------------------------------------------------------------------------

## 3. Exportación de Resultados y Estructura de Artefactos

La función
[`exportar_resultados()`](https://paulesantos.github.io/peruocc/reference/exportar_resultados.md)
toma el objeto devuelto por cualquier búsqueda y genera artefactos
estructurados y listos para interoperabilidad:

``` r

# Exportación completa (por defecto a processed/ de peruocc_data_dir)
archivos <- exportar_resultados(resultado)

# Exportación personalizada a otra carpeta y formatos específicos:
exportar_resultados(
  resultado = resultado,
  dir_salida = "mis_analisis/capas",
  formatos = c("csv", "geojson")
)
```

### Estructura del Directorio de Salida

Cuando se utiliza `peruocc_data_dir("peruocc-output")`, la estructura
queda organizada de la siguiente manera:

``` text
peruocc-output/
├── cache/
│   ├── distritos_lima.rds                 # Geometrías oficiales cacheadas
│   └── distritos_peru_completo.rds
└── processed/
    ├── ocurrencias_distrito_miraflores_flora.csv
    ├── ocurrencias_distrito_miraflores_flora.geojson
    └── manifiesto_distrito_miraflores_flora.json
```

### Descripción de los Formatos Exportados

1.  **`ocurrencias_*.csv`**:
    - Tabla plana estandarizada según el estándar internacional **Darwin
      Core** (`scientificName`, `decimalLatitude`, `decimalLongitude`,
      `eventDate`, `source`, etc.).
2.  **`ocurrencias_*.geojson`**:
    - Capa espacial vectorial de puntos con proyección geográfica WGS84
      (EPSG:4326). Se puede arrastrar directamente a **QGIS**,
      **ArcGIS** o visores web (**Leaflet**, **Mapbox**).
3.  **`manifiesto_*.json`**:
    - Manifiesto de auditoría y reproducibilidad científica. Registra:
      - Fecha y hora exacta de la consulta (UTC).
      - Versiones de R y paquetes utilizados (`sf`, `rgbif`, `rinat`,
        `geoperu`).
      - Polígono de consulta en formato WKT (*Well-Known Text*).
      - Parámetros y filtros aplicados (fechas, límites por API,
        reinos).
4.  **`results/mapa_*.png`** (opcional):
    - Gráficos cartográficos en alta resolución (300 DPI) generados por
      `graficar_ocurrencias(..., guardar_mapa = TRUE)`.

------------------------------------------------------------------------

## 4. Visualización Cartográfica con `graficar_ocurrencias()`

La función
[`graficar_ocurrencias()`](https://paulesantos.github.io/peruocc/reference/graficar_ocurrencias.md)
produce composiciones visuales basadas en `ggplot2`, integrando la
delimitación poligonal oficial de fondo con las observaciones
superpuestas.

### Comparación por Proveedor de Datos (`source`)

``` r

# Visualizar diferenciando aportes de GBIF vs iNaturalist
mapa_fuente <- graficar_ocurrencias(
  resultado_lista = resultado,
  color_por = "source"
)

print(mapa_fuente)
```

### Comparación por Reino Biológico (`kingdom`)

``` r

# Visualizar distribución por reinos (Plantae, Animalia, Fungi, etc.)
mapa_reino <- graficar_ocurrencias(
  resultado_lista = resultado,
  color_por = "kingdom"
)

print(mapa_reino)
```

### Exportar el Mapa Directamente a Imagen

``` r

# Genera y guarda automáticamente el mapa en results/ en formato PNG a 300 DPI
mapa_guardado <- graficar_ocurrencias(
  resultado_lista = resultado,
  color_por = "source",
  guardar_mapa = TRUE
)
```

------------------------------------------------------------------------

## 5. Integración con SIG y Flujos Espaciales

Las capas GeoJSON generadas pueden volver a cargarse en R para análisis
espaciales posteriores (como modelos de distribución de especies o
buffers):

``` r

library(sf)

# Cargar la capa de ocurrencias exportada
capa_ocurrencias <- sf::st_read("peruocc-output/processed/ocurrencias_distrito_miraflores_flora.geojson")

# Inspección rápida
print(capa_ocurrencias)
```
