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
#> ── Cargando peruocc ────────────────────────────────────────────────── v0.1.0 ──
#> ✔ geoperu 0.0.1   • Límites cartográficos oficiales del Perú
#> ✔ rgbif   3.8.5   • Extracción de ocurrencias desde GBIF
#> ✔ rinat   0.1.10  • Observaciones ciudadanas de iNaturalist
#> ✔ sf      1.1.2   • Operaciones geométricas y filtros espaciales
# Configurar directorio donde se guardarán caché, resultados y manifiestos
peruocc_data_dir("peruocc-output")

# Obtener la geometría oficial de un distrito
distrito_sf <- obtener_poligono_distrito(
  distrito = "Machupicchu",
  departamento = "Cusco",
  provincia = "Urubamba"
)
#> ℹ Cargando límites de CUSCO desde el caché local...

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
#> ℹ Cargando límites de MADRE DE DIOS desde el caché local...

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

## 5. Estrategias de Particionamiento Espacial para Grandes Unidades

El territorio peruano presenta provincias y distritos de enorme
extensión territorial (particularmente en la cuenca amazónica, como
*Maynas*, *Tambopata* o *La Convención*). Consultar estas áreas extensas
en una única llamada puede provocar tiempos de espera agotados o
truncamiento de registros por los límites máximos de las APIs.

`peruocc` ofrece el argumento `estrategia_espacial` en
[`buscar_especies_peru()`](https://paulesantos.github.io/peruocc/reference/buscar_especies_peru.md)
y
[`buscar_especies_poligono()`](https://paulesantos.github.io/peruocc/reference/buscar_especies_poligono.md):

``` r

buscar_especies_peru(
  nombre = "Tambopata",
  nivel = "provincia",
  departamento = "Madre de Dios",
  estrategia_espacial = "auto",   # "auto", "segmentada" o "directa"
  max_area_ha = 1000,             # Área objetivo por tesela
  max_lotes = 16L                 # Límite de macro-bloques de seguridad
)
```

### Modos de Operación:

1.  **`"auto"` (Predeterminado)**:
    - En **provincias**, descarga distrito por distrito y consolida al
      final, garantizando que si un distrito falla, los demás queden
      guardados en checkpoints `.rds`.
    - En **distritos o polígonos extensos** (superiores a 50,000 ha),
      divide la geometría automáticamente en macro-bloques de teselación
      espacial para realizar consultas en paralelo seguro.
2.  **`"segmentada"`**:
    - Fuerza la división del polígono en una cuadrícula adaptativa
      basada en `max_area_ha`. Ideal para grandes áreas de estudio o
      estudios de alta densidad de registros.
3.  **`"directa"`**:
    - Envía el polígono completo en una sola llamada sin teselar.
      Recomendado únicamente para distritos urbanos pequeños o
      geometrías de reducida extensión.

### Checkpoints y Resiliencia en Lotes

Cada lote procesado escribe un checkpoint intermedio en el directorio de
caché
([`peruocc_data_dir()`](https://paulesantos.github.io/peruocc/reference/peruocc_data_dir.md)).
Si la conexión a internet se interrumpe durante una descarga extensa,
volver a ejecutar la misma función **reanudará la extracción desde el
último lote completado**, sin repetir consultas previas ni duplicar
registros.

------------------------------------------------------------------------

## Siguientes Pasos

Para consultar delimitaciones fuera del marco administrativo oficial
(como Áreas Naturales Protegidas, buffers o shapefiles propios),
consulta la viñeta especializada:

- **[Búsqueda de Ocurrencias con Polígonos
  Personalizados](https://paulesantos.github.io/peruocc/articles/busqueda_poligono_usuario.md)**
