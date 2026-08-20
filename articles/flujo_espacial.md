# Flujo Espacial y Filtrado Topológico Riguroso

## Arquitectura Espacial de peruocc

Uno de los principales retos al consultar APIs globales de biodiversidad
mediante límites geográficos es la inconsistencia topológica y los
falsos positivos en los bordes perimetrales. `peruocc` implementa un
flujo espacial en 5 fases:

``` text
               ┌──────────────────────────────┐
               │    Unidad Administrativa     │
               │   (Distrito o Provincia)     │
               └──────────────┬───────────────┘
                              │
               ┌──────────────▼──────────────┐
               │  Geometría Oficial geoperu   │
               │   + Validación / Caché RDS   │
               └──────────────┬───────────────┘
                              │
             ┌────────────────┴────────────────┐
             │                                 │
  ┌──────────▼──────────┐           ┌──────────▼──────────┐
  │  Consulta a GBIF    │           │ Consulta iNaturalist│
  │  (WKT / Taxonomía)  │           │   (Bounding Box)    │
  └──────────┬──────────┘           └──────────┬──────────┘
             │                                 │
             └────────────────┬────────────────┘
                              │
               ┌──────────────▼──────────────┐
               │ Filtrado Espacial en R       │
               │ (sf::st_intersects exacto)  │
               └──────────────┬───────────────┘
                              │
               ┌──────────────▼──────────────┐
               │ Objeto Consolidado Final     │
               └─────────────────────────────┘
```

------------------------------------------------------------------------

## 1. Extracción de Geometrías y Caché Departamental

Para evitar descargas repetitivas y lentas desde la infraestructura de
datos espaciales, `peruocc` descarga los límites departamentales una
sola vez y los almacena en archivos locales binarios `.rds`:

``` r

library(peruocc)
# Configurar directorio donde se guardarán caché, resultados y manifiestos
peruocc_data_dir("peruocc-output")

# Obtener la geometría oficial de un distrito
distrito_sf <- obtener_poligono_distrito(
  distrito = "Machupicchu",
  departamento = "Cusco",
  provincia = "Urubamba"
)
#> [SPATIAL] Cargando limites de CUSCO desde el cache local...

distrito_sf
#> Simple feature collection with 1 feature and 4 fields
#> Geometry type: POLYGON
#> Dimension:     XY
#> Bounding box:  xmin: -72.60072 ymin: -13.3354 xmax: -72.38303 ymax: -13.08235
#> Geodetic CRS:  WGS 84
#>   departamento provincia    distrito     capital                       geometry
#> 1        CUSCO  URUBAMBA MACHUPICCHU MACHUPICCHU POLYGON ((-72.40501 -13.170...
```

### Disolución Provincial

Al solicitar una provincia, el paquete recupera todos los distritos
constituyentes y realiza una unión espacial
([`sf::st_union`](https://r-spatial.github.io/sf/reference/geos_combine.html)):

``` r

# Obtener polígono provincial unificado
provincia_sf <- obtener_poligono_provincia(
  provincia = "Tambopata",
  departamento = "Madre de Dios"
)
#> [SPATIAL] Cargando limites de MADRE DE DIOS desde el cache local...

provincia_sf
#> Simple feature collection with 1 feature and 3 fields
#> Geometry type: POLYGON
#> Dimension:     XY
#> Bounding box:  xmin: -72.21888 ymin: -13.34172 xmax: -68.65228 ymax: -11.03353
#> Geodetic CRS:  WGS 84
#>    departamento provincia distrito                       geometry
#> 1 MADRE DE DIOS TAMBOPATA     <NA> POLYGON ((-70.03839 -12.608...
```

------------------------------------------------------------------------

## 2. Orientación Geométrica Antihoraria (CCW)

Las especificaciones OGC y la API de GBIF exigen que los anillos
exteriores de los polígonos sigan una orientación antihoraria
(*Counter-Clockwise - CCW*) y los anillos interiores (huecos) sigan
orientación horaria.

`peruocc` valida y corrige automáticamente la orientación mediante el
cálculo del área con signo (Fórmula de Shoelace):

``` math
\text{Área} = \frac{1}{2} \sum_{i=1}^{n-1} (x_i y_{i+1} - x_{i+1} y_i)
```

------------------------------------------------------------------------

## 3. Simplificación Métrica Adaptativa para APIs

La API de GBIF impone restricciones estrictas en la longitud de las
cadenas WKT (Well-Known Text). Para polígonos administrativos con bordes
complejos, `peruocc`:

1.  Proyecta temporalmente a la zona UTM correspondiente según la
    longitud geográfica (Zona 17S, 18S o 19S en el Perú).
2.  Aplica simplificación topológica en metros
    (`sf::st_simplify(dTolerance = ...)`).
3.  Transforma de vuelta a WGS84 (EPSG:4326) para generar el WKT de
    consulta.

------------------------------------------------------------------------

## 4. Filtrado Espacial Exacto en Memoria

Dado que iNaturalist solo admite filtrado por caja delimitadora
(*Bounding Box*) y GBIF puede recibir un WKT simplificado, los registros
crudos obtenidos pueden contener puntos fuera del perímetro oficial.

`peruocc` resuelve esto convirtiendo todos los registros recuperados a
geometrías de punto y ejecutando una intersección topológica estricta
con el polígono detallado original:

``` r

# sf::st_intersects(puntos_sf, poligono_original_sf)
```

Garantizando que el 100% de las ocurrencias retenidas se encuentren
verdaderamente dentro de la unidad territorial elegida.

------------------------------------------------------------------------

## 5. Búsqueda con Polígonos Personalizados (Shapefile, GeoJSON, GPKG)

Además de los límites administrativos oficiales del Perú, `peruocc`
permite suministrar cualquier delimitación espacial personalizada
mediante
[`buscar_especies_poligono()`](https://paulesantos.github.io/peruocc/reference/buscar_especies_poligono.md):

### Opción A: Cargar desde un archivo espacial en disco

``` r

# Consulta usando un archivo Shapefile o GeoJSON (por ejemplo, un Área Natural Protegida)
resultado_anp <- buscar_especies_poligono(
  poligono = "capas/reserva_nacional_pacaya_samiria.geojson",
  nombre = "RN Pacaya Samiria",
  grupo = "fauna",
  limite_por_api = 500
)
```

### Opción B: Usar un objeto espacial `sf` creado en R

``` r

library(sf)

# Crear un buffer de 5 km alrededor de un punto de muestreo
punto <- sf::st_sfc(sf::st_point(c(-77.03, -12.05)), crs = 4326)
buffer_sf <- sf::st_buffer(sf::st_transform(punto, 32718), dist = 5000)
buffer_sf <- sf::st_transform(buffer_sf, 4326)

# Consultar biodiversidad dentro del buffer
resultado_buffer <- buscar_especies_poligono(
  poligono = buffer_sf,
  nombre = "Buffer 5km Centro Lima",
  grupo = "flora"
)
```

La función ejecuta automáticamente la validación del sistema de
coordenadas (CRS), repara geometrías no válidas y aplica el mismo
filtrado espacial y consolidación que en las búsquedas distritales y
provinciales.
