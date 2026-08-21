# Verifica y, opcionalmente, instala las dependencias de `peruocc`

Comprueba la disponibilidad de los paquetes requeridos para límites
administrativos, operaciones espaciales, consultas a GBIF/iNaturalist,
visualización y exportación. Úsela al preparar una instalación nueva o
para diagnosticar un error de carga.

## Usage

``` r
verificar_y_configurar_entorno(instalar = FALSE)
```

## Arguments

- instalar:

  Lógico de longitud uno. Con `FALSE` (predeterminado) informa los
  paquetes faltantes mediante un error, sin cambiar el sistema. Con
  `TRUE` intenta instalarlos desde el repositorio configurado de R;
  requiere conexión a Internet y permisos de escritura en la biblioteca
  de paquetes.

## Value

Invisiblemente `TRUE` si todas las dependencias están disponibles.

## Examples

``` r
if (FALSE) { # \dontrun{
verificar_y_configurar_entorno()
verificar_y_configurar_entorno(instalar = TRUE)
} # }
```
