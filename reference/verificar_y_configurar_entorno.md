# Verifica las dependencias de `peruocc`

Comprueba la disponibilidad de los paquetes requeridos para límites
administrativos, operaciones espaciales, consultas a GBIF/iNaturalist,
visualización y exportación. Úsela al preparar una instalación nueva o
para diagnosticar un error de carga.

## Usage

``` r
verificar_y_configurar_entorno()
```

## Value

Invisiblemente `TRUE` si todas las dependencias están disponibles.

## Examples

``` r
verificar_y_configurar_entorno()
#> ✔ Todas las dependencias requeridas están disponibles.
```
