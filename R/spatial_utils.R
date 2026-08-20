# spatial_utils.R
# Funciones auxiliares para el procesamiento espacial de poligonos de distritos y provincias de Peru.

# Funcion interna para normalizar cadenas de texto (quitar tildes, mayusculas, etc.)
normalizar_texto <- function(texto) {
  if (is.null(texto)) return(NULL)
  texto <- toupper(texto)
  # Reemplazar caracteres especiales y acentos en espanol
  texto <- chartr("\u00c1\u00c9\u00cd\u00d3\u00da\u00dc\u00d1", "AEIOUDN", texto)
  # Quitar puntuaciones y caracteres no alfanumericos (mantener espacios)
  texto <- gsub("[^A-Z0-9 ]", "", texto)
  texto <- trimws(texto)
  return(texto)
}

# Listado oficial de departamentos en geoperu
departamentos_oficiales <- function() {
  c("AMAZONAS", "ANCASH", "APURIMAC", "AREQUIPA", "AYACUCHO", 
    "CAJAMARCA", "CALLAO", "CUSCO", "HUANCAVELICA", "HUANUCO", 
    "ICA", "JUNIN", "LA LIBERTAD", "LAMBAYEQUE", "LIMA", 
    "LORETO", "MADRE DE DIOS", "MOQUEGUA", "PASCO", "PIURA", 
    "PUNO", "SAN MARTIN", "TACNA", "TUMBES", "UCAYALI")
}

# Helper interno para cargar geometrias departamentales con cache
cargar_mapa_departamental <- function(departamento = NULL) {
  loadNamespace("sf")
  deps_oficiales <- departamentos_oficiales()
  departamento_norm <- normalizar_texto(departamento)
  
  if (!is.null(departamento_norm)) {
    deps_norm <- sapply(deps_oficiales, normalizar_texto)
    indice_dep <- which(deps_norm == departamento_norm)
    
    if (length(indice_dep) == 0) {
      stop(sprintf("Error: El departamento '%s' no es valido en el Peru.", departamento))
    }
    
    dep_oficial <- deps_oficiales[indice_dep]
    dep_clean <- gsub(" ", "_", tolower(departamento_norm))
    rds_path <- ruta_cache(sprintf("distritos_%s.rds", dep_clean))
    
    if (file.exists(rds_path)) {
      cat(sprintf("[SPATIAL] Cargando limites de %s desde el cache local...\n", dep_oficial))
      mapa <- readRDS(rds_path)
    } else {
      cat(sprintf("[SPATIAL] Descargando limites de %s via geoperu...\n", dep_oficial))
      mapa <- tryCatch({
        geoperu::get_geo_peru(geography = dep_oficial, level = "dep", simplified = FALSE, showProgress = FALSE)
      }, error = function(e) {
        stop(sprintf("Error al descargar limites de geoperu: %s", e$message))
      })
      saveRDS(mapa, rds_path)
    }
    if (!inherits(mapa, "sf")) mapa <- sf::st_as_sf(mapa)
    return(mapa)
  }
  
  # Si no se especifica departamento, buscar primero en cache
  dir_c <- ruta_cache()
  archivos_cache <- list.files(dir_c, pattern = "^distritos_.*\\.rds$", full.names = TRUE)
  archivos_cache <- archivos_cache[!grepl("distritos_peru_completo.rds$", archivos_cache)]
  
  if (length(archivos_cache) > 0) {
    cat("[SPATIAL] Cargando datos disponibles desde cache local...\n")
    lista_mapas <- lapply(archivos_cache, readRDS)
    mapa_acumulado <- do.call(rbind, lista_mapas)
    if (!inherits(mapa_acumulado, "sf")) mapa_acumulado <- sf::st_as_sf(mapa_acumulado)
    return(mapa_acumulado)
  }
  
  rds_completo <- ruta_cache("distritos_peru_completo.rds")
  if (file.exists(rds_completo)) {
    cat("[SPATIAL] Cargando base de datos completa desde cache local...\n")
    mapa <- readRDS(rds_completo)
    if (!inherits(mapa, "sf")) mapa <- sf::st_as_sf(mapa)
    return(mapa)
  }
  
  cat("[SPATIAL] Departamento no especificado. Descargando limites distritales del Peru via geoperu...\n")
  lista_todos <- list()
  for (dep in deps_oficiales) {
    dep_clean <- gsub(" ", "_", tolower(normalizar_texto(dep)))
    rds_path <- ruta_cache(sprintf("distritos_%s.rds", dep_clean))
    
    if (file.exists(rds_path)) {
      lista_todos[[dep]] <- readRDS(rds_path)
    } else {
      cat(sprintf("  - Descargando departamento: %s...\n", dep))
      dep_sf <- tryCatch({
        geoperu::get_geo_peru(geography = dep, level = "dep", simplified = FALSE, showProgress = FALSE)
      }, error = function(e) {
        cat(sprintf("    Error al descargar %s: %s\n", dep, e$message))
        NULL
      })
      if (!is.null(dep_sf)) {
        saveRDS(dep_sf, rds_path)
        lista_todos[[dep]] <- dep_sf
      }
    }
  }
  mapa <- do.call(rbind, lista_todos)
  saveRDS(mapa, rds_completo)
  cat("[SPATIAL] Cache local completo creado con exito.\n")
  if (!inherits(mapa, "sf")) mapa <- sf::st_as_sf(mapa)
  return(mapa)
}

#' Obtiene el poligono de un distrito especifico en el Peru
#'
#' @param distrito Nombre del distrito (requerido).
#' @param departamento Nombre del departamento (opcional, para resolver ambiguedades).
#' @param provincia Nombre de la provincia (opcional, para resolver ambiguedades).
#' @return Un objeto sf con el poligono del distrito.
#' @export
obtener_poligono_distrito <- function(distrito, departamento = NULL, provincia = NULL) {
  loadNamespace("sf")
  if (missing(distrito) || is.null(distrito)) {
    stop("Error: Debe proporcionar el nombre de un distrito.")
  }
  
  distrito_norm <- normalizar_texto(distrito)
  provincia_norm <- normalizar_texto(provincia)
  departamento_norm <- normalizar_texto(departamento)
  
  mapa <- cargar_mapa_departamental(departamento = departamento)
  
  distritos_mapa_norm <- sapply(mapa$distrito, normalizar_texto)
  provincias_mapa_norm <- sapply(mapa$provincia, normalizar_texto)
  departamentos_mapa_norm <- sapply(mapa$departamento, normalizar_texto)
  
  idx <- which(distritos_mapa_norm == distrito_norm)
  
  # Si no hubo coincidencia y buscamos en cache parcial, descargar completo
  if (length(idx) == 0 && is.null(departamento_norm)) {
    mapa_completo <- cargar_mapa_departamental(departamento = NULL)
    distritos_mapa_norm <- sapply(mapa_completo$distrito, normalizar_texto)
    provincias_mapa_norm <- sapply(mapa_completo$provincia, normalizar_texto)
    departamentos_mapa_norm <- sapply(mapa_completo$departamento, normalizar_texto)
    idx <- which(distritos_mapa_norm == distrito_norm)
    mapa <- mapa_completo
  }
  
  if (length(idx) == 0) {
    sugerencias <- unique(utils::head(mapa$distrito[agrep(distrito_norm, distritos_mapa_norm, max.distance = 0.1)], 5))
    mensaje_error <- paste0("Error: No se encontro el distrito '", distrito, "'.")
    if (length(sugerencias) > 0) {
      mensaje_error <- paste0(mensaje_error, " Quiso decir uno de estos?: ",
                              paste(sugerencias, collapse = ", "))
    }
    stop(mensaje_error)
  }
  
  if (!is.null(provincia_norm)) {
    idx <- idx[provincias_mapa_norm[idx] == provincia_norm]
  }
  
  if (!is.null(departamento_norm)) {
    idx <- idx[departamentos_mapa_norm[idx] == departamento_norm]
  }
  
  if (length(idx) > 1) {
    cat("\nSe encontraron multiples distritos con el nombre '", distrito, "':\n")
    for (i in idx) {
      cat(sprintf("  - Departamento: %s | Provincia: %s | Distrito: %s\n", 
                  mapa$departamento[i], 
                  mapa$provincia[i], 
                  mapa$distrito[i]))
    }
    stop("Ambiguedad detectada. Por favor especifique el parametro 'departamento' o 'provincia' para afinar la busqueda.")
  }
  
  if (length(idx) == 0) {
    stop(sprintf("Error: No se encontro el distrito '%s' con los filtros especificados.", distrito))
  }
  
  col_geom <- attr(mapa, "sf_column")
  geoms <- mapa[[col_geom]][idx]
  if (!inherits(geoms, "sfc")) {
    geoms <- sf::st_sfc(geoms, crs = sf::st_crs(mapa))
  }
  
  coincidencias <- sf::st_sf(
    departamento = mapa$departamento[idx],
    provincia = mapa$provincia[idx],
    distrito = mapa$distrito[idx],
    capital = if ("capital" %in% names(mapa)) mapa$capital[idx] else NA_character_,
    geometry = geoms,
    crs = sf::st_crs(mapa)
  )
  
  coincidencias <- sf::st_make_valid(coincidencias)
  coincidencias <- asegurar_orientacion_antihoraria(coincidencias)
  
  return(coincidencias)
}

#' Obtiene el poligono consolidado de una provincia especifica en el Peru
#'
#' @param provincia Nombre de la provincia (requerido).
#' @param departamento Nombre del departamento (opcional, para resolver ambiguedades).
#' @return Un objeto sf con el poligono unificado de la provincia.
#' @export
obtener_poligono_provincia <- function(provincia, departamento = NULL) {
  loadNamespace("sf")
  if (missing(provincia) || is.null(provincia)) {
    stop("Error: Debe proporcionar el nombre de una provincia.")
  }
  
  provincia_norm <- normalizar_texto(provincia)
  departamento_norm <- normalizar_texto(departamento)
  
  mapa <- cargar_mapa_departamental(departamento = departamento)
  
  provincias_mapa_norm <- sapply(mapa$provincia, normalizar_texto)
  departamentos_mapa_norm <- sapply(mapa$departamento, normalizar_texto)
  
  idx <- which(provincias_mapa_norm == provincia_norm)
  
  if (length(idx) == 0 && is.null(departamento_norm)) {
    mapa_completo <- cargar_mapa_departamental(departamento = NULL)
    provincias_mapa_norm <- sapply(mapa_completo$provincia, normalizar_texto)
    departamentos_mapa_norm <- sapply(mapa_completo$departamento, normalizar_texto)
    idx <- which(provincias_mapa_norm == provincia_norm)
    mapa <- mapa_completo
  }
  
  if (length(idx) == 0) {
    sugerencias <- unique(utils::head(mapa$provincia[agrep(provincia_norm, provincias_mapa_norm, max.distance = 0.1)], 5))
    mensaje_error <- paste0("Error: No se encontro la provincia '", provincia, "'.")
    if (length(sugerencias) > 0) {
      mensaje_error <- paste0(mensaje_error, " Quiso decir una de estas?: ",
                              paste(sugerencias, collapse = ", "))
    }
    stop(mensaje_error)
  }
  
  if (!is.null(departamento_norm)) {
    idx <- idx[departamentos_mapa_norm[idx] == departamento_norm]
  }
  
  deps_encontrados <- unique(mapa$departamento[idx])
  if (length(deps_encontrados) > 1) {
    cat("\nSe encontraron provincias con el mismo nombre en multiples departamentos:\n")
    for (dep in deps_encontrados) {
      cat(sprintf("  - Departamento: %s | Provincia: %s\n", dep, provincia))
    }
    stop("Ambiguedad detectada. Por favor especifique el parametro 'departamento' para afinar la busqueda.")
  }
  
  col_geom <- attr(mapa, "sf_column")
  geoms <- mapa[[col_geom]][idx]
  if (!inherits(geoms, "sfc")) {
    geoms <- sf::st_sfc(geoms, crs = sf::st_crs(mapa))
  }
  
  coincidencias <- sf::st_sf(
    departamento = mapa$departamento[idx],
    provincia = mapa$provincia[idx],
    distrito = mapa$distrito[idx],
    geometry = geoms,
    crs = sf::st_crs(mapa)
  )
  
  dep_nombre <- coincidencias$departamento[1]
  prov_nombre <- coincidencias$provincia[1]
  
  geometria_union <- sf::st_union(sf::st_geometry(coincidencias))
  
  provincia_sf <- sf::st_sf(
    departamento = dep_nombre,
    provincia = prov_nombre,
    distrito = NA_character_,
    geometry = geometria_union,
    crs = sf::st_crs(coincidencias)
  )
  
  provincia_sf <- sf::st_make_valid(provincia_sf)
  provincia_sf <- asegurar_orientacion_antihoraria(provincia_sf)
  
  return(provincia_sf)
}

#' Obtiene el poligono de una unidad administrativa (distrito o provincia)
#'
#' @param nombre Nombre de la unidad administrativa.
#' @param nivel Nivel administrativo: "distrito" o "provincia" (def: "distrito").
#' @param departamento Nombre del departamento (opcional).
#' @param provincia Nombre de la provincia (opcional, para nivel "distrito").
#' @return Objeto sf con la geometria de la unidad.
#' @export
obtener_poligono_unidad <- function(nombre, nivel = c("distrito", "provincia"), departamento = NULL, provincia = NULL) {
  nivel <- match.arg(nivel)
  if (nivel == "distrito") {
    obtener_poligono_distrito(distrito = nombre, departamento = departamento, provincia = provincia)
  } else {
    obtener_poligono_provincia(provincia = nombre, departamento = departamento)
  }
}

#' Corrige la orientacion de un poligono sf para que el anillo exterior sea CCW
#' y los anillos interiores (huecos) sean CW.
#'
#' @param poly Objeto de tipo polygon de sf (lista de matrices).
#' @return Objeto de tipo polygon corregido.
corregir_poligono_ccw <- function(poly) {
  nuevo_poly <- list()
  for (j in seq_along(poly)) {
    ring <- poly[[j]]
    n <- nrow(ring)
    if (n >= 4) {
      x <- ring[, 1]
      y <- ring[, 2]
      # Formula de Shoelace para area con signo
      area <- sum(x[1:(n-1)] * y[2:n] - x[2:n] * y[1:(n-1)])
      
      # Anillo exterior (j == 1): Debe ser CCW (area > 0)
      # Anillos interiores/huecos (j > 1): Deben ser CW (area < 0)
      if (j == 1 && area < 0) {
        ring <- ring[n:1, ]
      } else if (j > 1 && area > 0) {
        ring <- ring[n:1, ]
      }
    }
    nuevo_poly[[j]] <- ring
  }
  return(sf::st_polygon(nuevo_poly))
}

#' Asegura que todas las geometrias de un objeto sf tengan orientacion antihoraria (CCW)
#'
#' @param sf_obj Objeto sf.
#' @return Objeto sf con orientaciones corregidas.
asegurar_orientacion_antihoraria <- function(sf_obj) {
  geom <- sf::st_geometry(sf_obj)
  for (i in seq_along(geom)) {
    feature <- geom[[i]]
    if (inherits(feature, "POLYGON")) {
      geom[[i]] <- corregir_poligono_ccw(feature)
    } else if (inherits(feature, "MULTIPOLYGON")) {
      geom[[i]] <- sf::st_multipolygon(lapply(feature, corregir_poligono_ccw))
    }
  }
  sf::st_geometry(sf_obj) <- geom
  return(sf_obj)
}

#' Simplifica un poligono sf o genera su bounding box si es muy complejo
#' para cumplir con el limite de longitud de caracteres de WKT.
#'
#' @param sf_obj Objeto sf.
#' @param max_char Limite de caracteres WKT (def: 1500).
#' @param tolerancia_inicial_metros Tolerancia inicial en metros para la simplificacion.
#' @return Objeto sf simplificado (o su bbox) apto para consulta.
simplificar_para_api <- function(sf_obj, max_char = 1500, tolerancia_inicial_metros = 100) {
  geom <- sf::st_geometry(sf_obj)
  wkt <- sf::st_as_text(geom[[1]])
  
  if (nchar(wkt) <= max_char) {
    return(sf_obj)
  }
  
  # Intentar simplificar progresivamente en UTM
  tol_metros <- tolerancia_inicial_metros
  sf_simp <- sf_obj
  for (i in 1:6) {
    sf_simp <- simplificar_poligono(sf_obj, tolerancia_metros = tol_metros)
    geom_simp <- sf::st_geometry(sf_simp)
    wkt_simp <- sf::st_as_text(geom_simp[[1]])
    
    if (nchar(wkt_simp) <= max_char) {
      cat(sprintf("[SPATIAL] Poligono simplificado con exito a tolerancia de %d metros (WKT: %d caracteres).\n", tol_metros, nchar(wkt_simp)))
      return(sf_simp)
    }
    
    tol_metros <- tol_metros * 3
  }
  
  # Si sigue siendo demasiado complejo, usar el Bounding Box como fallback
  cat("[SPATIAL] Poligono demasiado complejo. Usando Bounding Box como fallback para la consulta API.\n")
  bbox <- sf::st_bbox(sf_obj)
  sf_bbox <- sf::st_as_sf(sf::st_as_sfc(bbox))
  
  # Copiar metadatos si existen
  if (!is.null(sf_obj$distrito)) sf_bbox$distrito <- sf_obj$distrito[1]
  if (!is.null(sf_obj$departamento)) sf_bbox$departamento <- sf_obj$departamento[1]
  if (!is.null(sf_obj$provincia)) sf_bbox$provincia <- sf_obj$provincia[1]
  
  return(sf_bbox)
}

#' Simplifica un poligono de tipo sf usando proyecciones UTM
#'
#' @param sf_obj Objeto sf con la geometria.
#' @param tolerancia_metros Tolerancia de simplificacion en metros (def: 100 metros).
#' @return Objeto sf simplificado en EPSG:4326.
simplificar_poligono <- function(sf_obj, tolerancia_metros = 100) {
  if (tolerancia_metros <= 0) {
    return(sf_obj)
  }
  
  centroide <- sf::st_coordinates(sf::st_centroid(sf::st_union(sf::st_transform(sf_obj, 4326))))[1, ]
  zona_utm <- max(1, min(60, floor((centroide[1] + 180) / 6) + 1))
  epsg_utm <- 32700 + zona_utm
  sf_utm <- sf::st_transform(sf_obj, crs = epsg_utm)
  
  sf_utm_sim <- sf::st_simplify(sf_utm, preserveTopology = TRUE, dTolerance = tolerancia_metros)
  sf_wgs84 <- sf::st_transform(sf_utm_sim, crs = 4326)
  sf_wgs84 <- sf::st_make_valid(sf_wgs84)
  
  return(sf_wgs84)
}

#' Convierte un objeto sf a formato WKT (Well-Known Text) para consultas GBIF
#'
#' @param sf_obj Objeto sf.
#' @return Una cadena de texto en formato WKT.
poligono_a_wkt <- function(sf_obj) {
  geom <- sf::st_geometry(sf_obj)
  geom <- sf::st_make_valid(geom)
  wkt <- sf::st_as_text(geom[[1]])
  
  if (nchar(wkt) > 1500) {
    warning("La geometria WKT es muy larga (", nchar(wkt), " caracteres). Puede provocar fallos en la consulta API de GBIF. Considere aumentar el parametro de simplificacion.")
  }
  
  return(wkt)
}

#' Prepara y estandariza un poligono espacial provisto por el usuario
#'
#' Lee archivos espaciales (.shp, .geojson, .gpkg, .kml) o valida objetos `sf`/`sfc`,
#' asegurando que esten en proyeccion geografica WGS84 (EPSG:4326), con topologia valida
#' y estructurados para consultas de biodiversidad.
#'
#' @param poligono Objeto sf/sfc o ruta a un archivo espacial en disco.
#' @param nombre Nombre o etiqueta descriptiva para el poligono (opcional).
#' @return Un objeto sf estandarizado en EPSG:4326 con atributos descriptivos.
#' @export
preparar_poligono_usuario <- function(poligono, nombre = NULL) {
  loadNamespace("sf")
  
  if (missing(poligono) || is.null(poligono)) {
    stop("Error: Debe proporcionar un poligono (objeto sf o ruta a archivo espacial).")
  }
  
  # 1. Leer desde archivo si es character
  if (is.character(poligono)) {
    if (length(poligono) != 1L || !nzchar(trimws(poligono))) {
      stop("Error: La ruta del archivo espacial no es valida.")
    }
    if (!file.exists(poligono)) {
      stop(sprintf("Error: No se encontro el archivo espacial en la ruta: '%s'", poligono))
    }
    if (is.null(nombre) || !nzchar(trimws(nombre))) {
      nombre <- tools::file_path_sans_ext(basename(poligono))
    }
    sf_obj <- tryCatch({
      sf::st_read(poligono, quiet = TRUE)
    }, error = function(e) {
      stop(sprintf("Error al leer archivo espacial '%s': %s", poligono, e$message))
    })
  } else if (inherits(poligono, c("sf", "sfc", "Spatial"))) {
    sf_obj <- sf::st_as_sf(poligono)
    if (is.null(nombre) || !nzchar(trimws(nombre))) {
      nombre <- "Poligono_Personalizado"
    }
  } else {
    stop("Error: 'poligono' debe ser un objeto sf/sfc o una ruta a un archivo espacial (.shp, .geojson, .gpkg, .kml).")
  }
  
  if (nrow(sf_obj) == 0) {
    stop("Error: El objeto espacial no contiene registros ni geometrias.")
  }
  
  # 2. Validar y estandarizar CRS a EPSG:4326
  crs_actual <- sf::st_crs(sf_obj)
  if (is.na(crs_actual)) {
    warning("[SPATIAL] El poligono carece de sistema de referencia (CRS). Se asumira EPSG:4326 (WGS84).")
    sf::st_crs(sf_obj) <- 4326
  } else if (crs_actual != sf::st_crs(4326)) {
    cat(sprintf("[SPATIAL] Reproyectando geometria desde %s a EPSG:4326 (WGS84)...\n", crs_actual$input))
    sf_obj <- sf::st_transform(sf_obj, crs = 4326)
  }
  
  # 3. Validar y corregir topologia
  sf_obj <- sf::st_make_valid(sf_obj)
  
  # 4. Unificar si tiene multiples filas/poligonos
  if (nrow(sf_obj) > 1) {
    cat(sprintf("[SPATIAL] El archivo contiene %d elementos. Unificando en una sola entidad...\n", nrow(sf_obj)))
    geom_union <- sf::st_union(sf_obj)
    sf_obj <- sf::st_as_sf(sf::st_sfc(geom_union, crs = 4326))
  }
  
  # 5. Asegurar tipo poligonal
  geom_type <- as.character(sf::st_geometry_type(sf_obj, by_geometry = FALSE))
  if (!geom_type %in% c("POLYGON", "MULTIPOLYGON", "GEOMETRYCOLLECTION")) {
    stop(sprintf("Error: La geometria debe ser poligonal (POLYGON o MULTIPOLYGON), se detecto: %s", geom_type))
  }
  
  # 6. Asignar metadatos descriptivos
  sf_obj$unidad <- nombre
  sf_obj$distrito <- NA_character_
  sf_obj$provincia <- NA_character_
  sf_obj$departamento <- NA_character_
  
  return(sf_obj)
}

