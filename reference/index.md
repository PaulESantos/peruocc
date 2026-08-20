# Package index

## Consultas e Integración de Biodiversidad

Funciones principales para consultar, validar y consolidar ocurrencias
de GBIF e iNaturalist.

- [`buscar_especies_distrito()`](https://paulesantos.github.io/peruocc/reference/buscar_especies_distrito.md)
  : Realiza una busqueda combinada de especies en un distrito usando
  GBIF e iNaturalist
- [`buscar_especies_provincia()`](https://paulesantos.github.io/peruocc/reference/buscar_especies_provincia.md)
  : Realiza una busqueda combinada de especies en una provincia usando
  GBIF e iNaturalist
- [`buscar_especies_peru()`](https://paulesantos.github.io/peruocc/reference/buscar_especies_peru.md)
  : Realiza una busqueda combinada de especies en una unidad
  administrativa del Peru
- [`buscar_especies_poligono()`](https://paulesantos.github.io/peruocc/reference/buscar_especies_poligono.md)
  : Realiza una busqueda combinada de especies en un poligono
  personalizado provisto por el usuario

## Geometrías y Unidades Administrativas

Extracción y preparación de geometrías espaciales oficiales de geoperu o
personalizadas.

- [`obtener_poligono_distrito()`](https://paulesantos.github.io/peruocc/reference/obtener_poligono_distrito.md)
  : Obtiene el poligono de un distrito especifico en el Peru
- [`obtener_poligono_provincia()`](https://paulesantos.github.io/peruocc/reference/obtener_poligono_provincia.md)
  : Obtiene el poligono consolidado de una provincia especifica en el
  Peru
- [`obtener_poligono_unidad()`](https://paulesantos.github.io/peruocc/reference/obtener_poligono_unidad.md)
  : Obtiene el poligono de una unidad administrativa (distrito o
  provincia)
- [`preparar_poligono_usuario()`](https://paulesantos.github.io/peruocc/reference/preparar_poligono_usuario.md)
  : Prepara y estandariza un poligono espacial provisto por el usuario

## Visualización Cartográfica

Generación de mapas espaciales con capas temáticas y distribución de
puntos.

- [`graficar_ocurrencias()`](https://paulesantos.github.io/peruocc/reference/graficar_ocurrencias.md)
  : Grafica el mapa de ocurrencias sobre el poligono de la unidad
  administrativa

## Exportación, Configuración y Directorios

Exportación de artefactos (CSV, GeoJSON, manifiesto), gestión del
entorno de trabajo y almacenamiento en caché.

- [`exportar_resultados()`](https://paulesantos.github.io/peruocc/reference/exportar_resultados.md)
  : Exporta los resultados de una busqueda de biodiversidad a disco
- [`verificar_y_configurar_entorno()`](https://paulesantos.github.io/peruocc/reference/verificar_y_configurar_entorno.md)
  : Verify package dependencies
- [`peruocc_data_dir()`](https://paulesantos.github.io/peruocc/reference/peruocc_data_dir.md)
  [`peruspecies_data_dir()`](https://paulesantos.github.io/peruocc/reference/peruocc_data_dir.md)
  : Configure the directory used for package artifacts

## Funciones Auxiliares y Topología Espacial

Procesamiento geométrico interno, WKT, orientación CCW y consultas
modulares.

- [`asegurar_orientacion_antihoraria()`](https://paulesantos.github.io/peruocc/reference/asegurar_orientacion_antihoraria.md)
  : Asegura que todas las geometrias de un objeto sf tengan orientacion
  antihoraria (CCW)
- [`corregir_poligono_ccw()`](https://paulesantos.github.io/peruocc/reference/corregir_poligono_ccw.md)
  : Corrige la orientacion de un poligono sf para que el anillo exterior
  sea CCW y los anillos interiores (huecos) sean CW.
- [`poligono_a_wkt()`](https://paulesantos.github.io/peruocc/reference/poligono_a_wkt.md)
  : Convierte un objeto sf a formato WKT (Well-Known Text) para
  consultas GBIF
- [`simplificar_poligono()`](https://paulesantos.github.io/peruocc/reference/simplificar_poligono.md)
  : Simplifica un poligono de tipo sf usando proyecciones UTM
- [`simplificar_para_api()`](https://paulesantos.github.io/peruocc/reference/simplificar_para_api.md)
  : Simplifica un poligono sf o genera su bounding box si es muy
  complejo para cumplir con el limite de longitud de caracteres de WKT.
- [`buscar_gbif_por_poligono()`](https://paulesantos.github.io/peruocc/reference/buscar_gbif_por_poligono.md)
  : Busca ocurrencias de especies en GBIF dentro de un poligono de
  distrito o provincia
- [`buscar_inat_por_poligono()`](https://paulesantos.github.io/peruocc/reference/buscar_inat_por_poligono.md)
  : Busca ocurrencias de especies en iNaturalist dentro de un poligono
  de distrito o provincia
