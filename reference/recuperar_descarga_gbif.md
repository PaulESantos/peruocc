# Recupera una descarga GBIF ya solicitada

**\[experimental\]**

Espera opcionalmente a que GBIF termine una descarga asincrona y guarda
el ZIP resultante en un directorio indicado de forma explicita. No crea
una solicitud nueva ni escribe en el directorio de trabajo.

## Usage

``` r
recuperar_descarga_gbif(descarga, dir_salida, esperar = TRUE)
```

## Arguments

- descarga:

  Clave de descarga de GBIF o resultado de
  [`crear_descarga_gbif()`](https://paulesantos.github.io/peruocc/reference/crear_descarga_gbif.md).

- dir_salida:

  Directorio donde se guardara el ZIP. Se crea si no existe.

- esperar:

  Si es `TRUE`, espera la finalizacion de GBIF antes de descargar.

## Value

Lista con `clave`, `archivo` y `directorio`.

## Examples

``` r
if (FALSE) { # \dontrun{
recuperada <- recuperar_descarga_gbif(
  "0016731-260928105237408", dir_salida = "datos/gbif"
)
} # }
```
