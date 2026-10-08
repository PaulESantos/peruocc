# Crea una descarga reproducible de ocurrencias desde GBIF

**\[experimental\]**

Envia una descarga mediada por GBIF para un poligono amplio. A
diferencia de `buscar_especies_*()`, este flujo no devuelve una muestra
inmediata: genera una clave de descarga y DOI citable. El formato
Parquet es la opcion predeterminada para volumenes grandes; requiere
`arrow` solo para leer el archivo posteriormente, no para solicitarlo.

## Usage

``` r
crear_descarga_gbif(
  poligono,
  nombre_cientifico = NULL,
  grupo = NULL,
  taxonomia = c("col", "backbone"),
  coincidencia_taxonomica = c("exacta", "permitir_fuzzy", "permitir_rango_superior"),
  filtros_calidad_gbif = filtros_calidad_gbif_predeterminados(),
  excluir_incidentes_geoespaciales = NULL,
  solo_ocurrencias_presentes = NULL,
  excluir_fosiles = NULL,
  excluir_especimenes_vivos = NULL,
  incertidumbre_max_m = NULL,
  permitir_incertidumbre_desconocida = NULL,
  distancia_min_centroide_m = NULL,
  licencias_gbif = NULL,
  formato = c("SIMPLE_PARQUET", "SIMPLE_CSV", "DWCA"),
  esperar = FALSE,
  dir_salida = NULL,
  tolerancia_simplificacion = 100,
  user = NULL,
  pwd = NULL,
  email = NULL,
  reintentos = configuracion_predeterminada()$reintentos_api
)

solicitar_descarga_gbif(...)
```

## Arguments

- poligono:

  Objeto espacial aceptado por
  [`preparar_poligono_usuario()`](https://paulesantos.github.io/peruocc/reference/preparar_poligono_usuario.md).

- nombre_cientifico:

  `NULL` o nombre cientifico a resolver en GBIF.

- grupo:

  `NULL`, `"flora"` o `"fauna"`.

- taxonomia:

  `"col"` (predeterminado) o `"backbone"`.

- coincidencia_taxonomica:

  Politica para coincidencias no exactas.

- filtros_calidad_gbif:

  Lista creada por
  [`filtros_calidad_gbif_predeterminados()`](https://paulesantos.github.io/peruocc/reference/filtros_calidad_gbif_predeterminados.md).

- excluir_incidentes_geoespaciales:

  Excluye incidencias espaciales conocidas cuando es `TRUE`; con `FALSE`
  no las filtra.

- solo_ocurrencias_presentes:

  Conserva solo registros `PRESENT` cuando es `TRUE`; con `FALSE` no
  aplica ese filtro.

- excluir_fosiles, excluir_especimenes_vivos:

  Excluyen esos tipos de registro cuando son `TRUE`.

- incertidumbre_max_m:

  Maxima incertidumbre espacial en metros.

- permitir_incertidumbre_desconocida:

  Conserva registros sin valor de incertidumbre al aplicar
  `incertidumbre_max_m`.

- distancia_min_centroide_m:

  Distancia minima a un centroide, en metros.

- licencias_gbif:

  Licencia o vector de licencias aceptadas por GBIF.

- formato:

  Formato solicitado a GBIF.

- esperar:

  Si es `TRUE`, espera a que GBIF termine y descarga el ZIP.

- dir_salida:

  Directorio opcional para el manifiesto y, cuando `esperar = TRUE`,
  directorio obligatorio para el ZIP.

- tolerancia_simplificacion:

  Tolerancia inicial, en metros, para simplificar poligonos con WKT
  extenso. La simplificacion conserva el poligono; nunca lo reemplaza
  por una caja delimitadora.

- user, pwd, email:

  Credenciales GBIF opcionales. Es preferible definir `GBIF_USER`,
  `GBIF_PWD` y `GBIF_EMAIL` como variables de entorno.

- reintentos:

  Entero positivo con el numero maximo de intentos para las operaciones
  remotas de GBIF.

- ...:

  Argumentos que se reenvian a `crear_descarga_gbif()`.

## Value

Lista con la clave, DOI, cita, resolucion taxonomica y, opcionalmente,
la ruta del archivo descargado.

## Examples

``` r
if (FALSE) { # \dontrun{
if (requireNamespace("sf", quietly = TRUE)) {
  poligono <- sf::st_sfc(
    sf::st_polygon(list(matrix(
      c(-77.05, -12.13, -77.01, -12.13, -77.01, -12.10, -77.05, -12.10, -77.05, -12.13),
      ncol = 2, byrow = TRUE
    ))),
    crs = 4326
  )
  # Requiere credenciales GBIF (GBIF_USER, GBIF_PWD, GBIF_EMAIL)
  crear_descarga_gbif(poligono, grupo = "aves")
}
} # }
```
