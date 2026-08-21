# Configura el directorio de trabajo de `peruocc`

Define el directorio raíz donde el paquete guarda resultados exportados
y, cuando se configura explícitamente, los límites y checkpoints de
consultas. La configuración se conserva durante la sesión de R mediante
la opción `peruocc.data_dir`; no modifica archivos de configuración
permanentes.

## Usage

``` r
peruocc_data_dir(path = NULL)

peruspecies_data_dir(path = NULL)
```

## Arguments

- path:

  Cadena de longitud uno con una ruta existente o por crear. Debe
  apuntar a una ubicación con permisos de escritura. Si es `NULL`, usa
  la opción ya configurada y, si no existe, crea `peruocc/` bajo el
  directorio de trabajo actual.

## Value

Invisiblemente, la ruta absoluta normalizada que quedó activa.

## Details

Los resultados se escriben en `processed/` y los límites o checkpoints
en `cache/` dentro de este directorio. Configure una ruta fuera del
repositorio cuando ejecute viñetas o análisis reproducibles para evitar
incorporar artefactos generados al paquete.

## Examples

``` r
dir_temporal <- file.path(tempdir(), "peruocc-ejemplo")
peruocc_data_dir(dir_temporal)
# consultar la ruta activa:
peruocc_data_dir()
```
