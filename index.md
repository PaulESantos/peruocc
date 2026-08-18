# Consulta de Ocurrencias de Especies en Distritos del Perú (GBIF & iNaturalist)

Este es un proyecto en R diseñado para buscar, descargar, filtrar y
mapear registros de ocurrencias de biodiversidad (flora y fauna) en
distritos del Perú. Utiliza la geometría de los límites distritales
oficiales como argumento espacial de búsqueda para consultar las bases
de datos de **GBIF** (Global Biodiversity Information Facility) y
**iNaturalist**.

La delimitación geográfica de los distritos se obtiene dinámicamente
utilizando el paquete **`geoperu`** (límites oficiales provistos por el
INEI).

## Características Principales

1.  **Búsqueda Espacial por Distritos**: Obtiene las divisiones
    distritales a partir de descargas dinámicas a nivel departamental
    vía
    [`geoperu::get_geo_peru()`](https://paulesantos.github.io/geoperu/reference/get_geo_peru.html).
2.  **Caché Local Eficiente (`.rds`)**:
    - `geoperu` descarga archivos GPKG desde internet. Para optimizar el
      rendimiento y ahorrar ancho de banda, el script implementa un
      **mecanismo de caché por departamento** en la carpeta `data/` (ej.
      `data/distritos_lima.rds`).
    - La primera consulta de un departamento tarda unos segundos debido
      a la descarga; las siguientes consultas en el mismo departamento
      se cargan instantáneamente desde el caché local en disco.
3.  **Normalización de Nombres**: Resuelve nombres de distritos de forma
    insensible a mayúsculas, minúsculas, tildes e incluye una función de
    sugerencias de autocompletado en caso de errores tipográficos.
4.  **Mapeo Avanzado de GBIF**: Convierte los polígonos a formato WKT
    (Well-Known Text) garantizando el sentido antihorario (CCW)
    requerido por GBIF.
5.  **Simplificación Progresiva y Bounding Box**: Si el polígono del
    distrito es muy complejo (\>1500 caracteres), lo simplifica de forma
    métrica utilizando proyecciones UTM. Si sigue siendo excesivamente
    grande, utiliza su caja delimitadora (Bounding Box) como fallback
    para la API.
6.  **Filtrado Espacial Riguroso en R**: Tanto para GBIF como para
    iNaturalist, el script realiza una intersección espacial exacta
    ([`sf::st_intersects`](https://r-spatial.github.io/sf/reference/geos_binary_pred.html))
    de los puntos recuperados con el polígono detallado original del
    distrito, descartando observaciones fuera de los límites.
7.  **Visualización y Exportación**: Genera mapas de alta resolución
    (300 DPI) con `ggplot2` y exporta los resultados tabulares
    unificados a archivos CSV y capas espaciales GeoJSON.

------------------------------------------------------------------------

## Estructura del Proyecto

``` text
D:\peru_species_project\
│
├── peru_species_project.Rproj     # Archivo de configuración del proyecto en RStudio
├── README.md                      # Esta guía en español
├── main.R                         # Script principal de prueba y casos de uso prácticos
│
├── R/                             # Módulos de funciones específicas
│   ├── setup.R                    # Instalador y verificador de la librería 'geoperu' y otras dependencias
│   ├── spatial_utils.R            # Funciones espaciales (descarga de geoperu, caché, CCW, simplificación)
│   ├── query_gbif.R               # Consultas y normalización para la API de GBIF
│   ├── query_inat.R               # Consultas y filtrado espacial para la API de iNaturalist
│   ├── query_combined.R           # Integración y guardado de resultados consolidado
│   └── visualize.R                # Generador de mapas con ggplot2 y sf
│
├── data/                          # raw/, cache/ y processed/; artefactos no versionados por defecto
├── results/                       # Figuras generadas
├── config/default.R               # Configuración versionada
├── tests/run_tests.R              # Pruebas sin acceso a red
└── scripts/lock_environment.R     # Generación explícita de renv.lock
```

------------------------------------------------------------------------

## Instalación y Configuración

### Requisitos Previos

1.  Tener instalado R en el sistema (versión 4.0 o superior
    recomendada).
2.  RStudio para ejecutar el proyecto cómodamente.

### Entorno reproducible

Las dependencias no se instalan automáticamente al ejecutar análisis. En
un entorno validado, cree el bloqueo de versiones una vez:

``` r

source("scripts/lock_environment.R")
```

Después restaure el entorno antes de ejecutar:

``` r

install.packages("renv") # sólo si aún no está disponible
renv::restore()
source("main.R")
```

`R/setup.R` únicamente verifica dependencias; la instalación manual
exige `verificar_y_configurar_entorno(instalar = TRUE)`.

------------------------------------------------------------------------

## Guía de Uso Rápido

Para ejecutar los casos de prueba por defecto, abra R o RStudio en este
directorio y ejecute:

``` r

source("main.R")
```

Esto generará tablas de ocurrencias e imágenes de mapas dentro de la
carpeta `data/` para: 1. Miraflores (Lima) - Flora. 2. Tambopata (Madre
de Dios) - Fauna. 3. Tarma (Junín) - Cantua buxifolia.

### Uso de las Funciones en R

#### 1. Buscar Ocurrencias en un Distrito

La función principal es
[`buscar_especies_distrito()`](https://paulesantos.github.io/peru_species_project/reference/buscar_especies_distrito.md)
definida en `R/query_combined.R`:

``` r

source("R/setup.R") # Cargar dependencias
source("R/spatial_utils.R")
source("R/query_gbif.R")
source("R/query_inat.R")
source("R/query_combined.R")
source("R/visualize.R")

# Buscar flora en el distrito de Miraflores, Lima (se descarga y almacena el caché de Lima)
resultado <- buscar_especies_distrito(
  distrito = "Miraflores",
  departamento = "Lima",
  provincia = "Lima",
  grupo = "flora",            # Filtros disponibles: "flora", "fauna" o NULL (todo)
  limite_por_api = 100,       # Máximo de registros por cada origen; NULL intenta descarga completa
  guardar_resultados = TRUE   # Exporta un archivo CSV y GeoJSON automáticamente
)
```

#### 2. Generar el Mapa

Use
[`graficar_ocurrencias()`](https://paulesantos.github.io/peru_species_project/reference/graficar_ocurrencias.md)
del módulo `R/visualize.R` para crear el mapa y guardarlo como PNG:

``` r

# Mapear coloreando por la fuente del registro (GBIF vs iNaturalist)
mapa <- graficar_ocurrencias(resultado, color_por = "source", guardar_mapa = TRUE)
```

------------------------------------------------------------------------

## Detalle Técnico de los Datos Obtenidos

El dataframe unificado final tiene la siguiente estructura de columnas
estandarizada:

| Columna | Tipo | Descripción |
|:---|:---|:---|
| `scientificName` | `character` | Nombre científico completo de la especie. |
| `occurrenceID` / `sourceRecordID` | `character` | Identificador persistente o identificador nativo del registro. |
| `sourceURL` | `character` | Enlace al registro en el proveedor. |
| `datasetKey`, `license`, `basisOfRecord` | `character` | Proveniencia y condiciones de reutilización cuando están disponibles. |
| `decimalLatitude` | `numeric` | Latitud del registro (WGS84). |
| `decimalLongitude` | `numeric` | Longitud del registro (WGS84). |
| `eventDate` | `character` | Fecha en la que ocurrió el avistamiento. |
| `taxonRank` | `character` | Rango taxonómico (especie, género, etc.). |
| `kingdom` | `character` | Reino (Plantae, Animalia, etc.). |
| `phylum` | `character` | Filo (solo GBIF). |
| `class` | `character` | Clase (solo GBIF). |
| `order` | `character` | Orden (solo GBIF). |
| `family` | `character` | Familia (solo GBIF). |
| `genus` | `character` | Género (solo GBIF). |
| `species` | `character` | Nombre de especie específico (solo GBIF). |
| `recordedBy` | `character` | Nombre del observador o colector del registro. |
| `coordinateUncertaintyInMeters` | `numeric` | Margen de error o incertidumbre posicional en metros. |
| `source` | `character` | Origen de los datos (`GBIF` o `iNaturalist`). |
| `district` | `character` | Nombre del distrito en el que se ubica. |

## Reproducibilidad y trazabilidad

Cada corrida exportada crea nombres únicos basados en fecha/hora UTC y
un manifiesto JSON en `data/processed/`. El manifiesto conserva
parámetros, WKT y CRS del polígono, versiones de R/paquetes, conteos y
rutas de los artefactos. Los registros incluyen identificadores y
procedencia de la fuente cuando la API los entrega.

GBIF e iNaturalist son fuentes vivas: restaurar el entorno reproduce el
método, no necesariamente el resultado de una fecha distinta. Para una
reproducción exacta archive las respuestas originales de API junto con
el manifiesto. El límite por API puede truncar la cobertura y no debe
interpretarse como un inventario exhaustivo.

Use `limite_por_api = NULL` para solicitar la descarga completa
paginada. GBIF la completará sólo hasta 100 000 resultados de búsqueda;
por encima de ese umbral el flujo se detiene y exige una descarga masiva
GBIF con DOI. iNaturalist se completa mediante `rinat` hasta 10 000
observaciones; por encima de ese total el flujo se detiene y exige la
exportación oficial o una extracción temporalmente particionada. El
manifiesto informa el total reportado por cada API y si la descarga se
completó.

Ejecute las pruebas sin red con:

``` r

source("tests/run_tests.R")
```
