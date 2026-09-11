# Configura el directorio de trabajo de `peruocc`

Define el directorio raíz donde el paquete guarda resultados exportados
y, cuando se configura explícitamente, los límites y checkpoints de
consultas. La configuración se conserva durante la sesión de R mediante
la opción `peruocc.data_dir`; no modifica archivos de configuración
permanentes ni crea directorios por defecto en el espacio de trabajo del
usuario.

## Usage

``` r
peruocc_data_dir(path = NULL)

peruspecies_data_dir(path = NULL)
```

## Arguments

- path:

  Cadena de longitud uno con una ruta existente o por crear. Debe
  apuntar a una ubicación con permisos de escritura. Si es `NULL`,
  devuelve la ruta configurada actualmente (o `NULL` si no se ha
  configurado ninguna).

## Value

Invisiblemente, la ruta absoluta normalizada activa, o `NULL` si no se
ha definido un directorio.

## Details

Cuando está configurado, los resultados se escriben en `processed/` y
los checkpoints en `cache/` dentro de este directorio.

## Examples

``` r
dir_temporal <- file.path(tempdir(), "peruocc-ejemplo")
peruocc_data_dir(dir_temporal)
# consultar la ruta activa:
peruocc_data_dir()
#> [1] "/tmp/RtmpC0h4Ul/peruocc-ejemplo"
```
