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
  deps_oficiales <- departamentos_oficiales()
  departamento_norm <- normalizar_texto(departamento)
  
  dir.create(ruta_peruocc("cache"), recursive = TRUE, showWarnings = FALSE)
  
  if (!is.null(departamento_norm)) {
    deps_norm <- sapply(deps_oficiales, normalizar_texto)
    indice_dep <- which(deps_norm == departamento_norm)
    
    if (length(indice_dep) == 0) {
      stop(sprintf("Error: El departamento '%s' no es valido en el Peru.", departamento))
    }
    
    dep_oficial <- deps_oficiales[indice_dep]
    dep_clean <- gsub(" ", "_", tolower(departamento_norm))
    rds_path <- ruta_peruocc("cache", sprintf("distritos_%s.rds", dep_clean))
    
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
    return(mapa)
  }
  
  # Si no se especifica departamento, buscar primero en cache
  archivos_cache <- list.files(ruta_peruocc("cache"), pattern = "^distritos_.*\\.rds$", full.names = TRUE)
  archivos_cache <- archivos_cache[!grepl("distritos_peru_completo.rds$", archivos_cache)]
  
  if (length(archivos_cache) > 0) {
    cat("[SPATIAL] Cargando datos disponibles desde cache local...\n")
    lista_mapas <- lapply(archivos_cache, readRDS)
    mapa_acumulado <- do.call(rbind, lista_mapas)
    return(mapa_acumulado)
  }
  
  rds_completo <- ruta_peruocc("cache", "distritos_peru_completo.rds")
  if (file.exists(rds_completo)) {
    cat("[SPATIAL] Cargando base de datos completa desde cache local...\n")
    return(readRDS(rds_completo))
  }
  
  cat("[SPATIAL] Departamento no especificado. Descargando limites distritales del Peru via geoperu...\n")
  lista_todos <- list()
  for (dep in deps_oficiales) {
    dep_clean <- gsub(" ", "_", tolower(normalizar_texto(dep)))
    rds_path <- ruta_peruocc("cache", sprintf("distritos_%s.rds", dep_clean))
    
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
  if (missing(distrito) || is.null(distrito)) {
    stop("Error: Debe proporcionar el nombre de un distrito.")
  }
  
  distrito_norm <- normalizar_texto(distrito)
  provincia_norm <- normalizar_texto(provincia)
  departamento_norm <- normalizar_texto(departamento)
  
  mapa <- cargar_mapa_departamental(departamento = departamento)
  
  mapa$distrito_norm <- sapply(mapa$distrito, normalizar_texto)
  mapa$provincia_norm <- sapply(mapa$provincia, normalizar_texto)
  mapa$departamento_norm <- sapply(mapa$departamento, normalizar_texto)
  
  coincidencias <- mapa[mapa$distrito_norm == distrito_norm, ]
  
  # Si no hubo coincidencia y buscamos en cache parcial, descargar completo
  if (nrow(coincidencias) == 0 && is.null(departamento_norm)) {
    mapa_completo <- cargar_mapa_departamental(departamento = NULL)
    mapa_completo$distrito_norm <- sapply(mapa_completo$distrito, normalizar_texto)
    mapa_completo$provincia_norm <- sapply(mapa_completo$provincia, normalizar_texto)
    mapa_completo$departamento_norm <- sapply(mapa_completo$departamento, normalizar_texto)
    coincidencias <- mapa_completo[mapa_completo$distrito_norm == distrito_norm, ]
    mapa <- mapa_completo
  }
  
  if (nrow(coincidencias) == 0) {
    sugerencias <- unique(utils::head(mapa$distrito[agrep(distrito_norm, mapa$distrito_norm, max.distance = 0.1)], 5))
    mensaje_error <- paste0("Error: No se encontro el distrito '", distrito, "'.")
    if (length(sugerencias) > 0) {
      mensaje_error <- paste0(mensaje_error, " Quiso decir uno de estos?: ",
                              paste(sugerencias, collapse = ", "))
    }
    stop(mensaje_error)
  }
  
  if (!is.null(provincia_norm)) {
    coincidencias <- coincidencias[coincidencias$provincia_norm == provincia_norm, ]
  }
  
  if (!is.null(departamento_norm)) {
    coincidencias <- coincidencias[coincidencias$departamento_norm == departamento_norm, ]
  }
  
  if (nrow(coincidencias) > 1) {
    cat("\nSe encontraron multiples distritos con el nombre '", distrito, "':\n")
    for (i in 1:nrow(coincidencias)) {
      cat(sprintf("  - Departamento: %s | Provincia: %s | Distrito: %s\n", 
                  coincidencias$departamento[i], 
                  coincidencias$provincia[i], 
                  coincidencias$distrito[i]))
    }
    stop("Ambiguedad detectada. Por favor especifique el parametro 'departamento' o 'provincia' para afinar la busqueda.")
  }
  
  coincidencias$distrito_norm <- NULL
  coincidencias$provincia_norm <- NULL
  coincidencias$departamento_norm <- NULL
  
  coincidencias <- sf::st_as_sf(coincidencias)
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
  if (missing(provincia) || is.null(provincia)) {
    stop("Error: Debe proporcionar el nombre de una provincia.")
  }
  
  provincia_norm <- normalizar_texto(provincia)
  departamento_norm <- normalizar_texto(departamento)
  
  mapa <- cargar_mapa_departamental(departamento = departamento)
  
  mapa$provincia_norm <- sapply(mapa$provincia, normalizar_texto)
  mapa$departamento_norm <- sapply(mapa$departamento, normalizar_texto)
  
  coincidencias <- mapa[mapa$provincia_norm == provincia_norm, ]
  
  if (nrow(coincidencias) == 0 && is.null(departamento_norm)) {
    mapa_completo <- cargar_mapa_departamental(departamento = NULL)
    mapa_completo$provincia_norm <- sapply(mapa_completo$provincia, normalizar_texto)
    mapa_completo$departamento_norm <- sapply(mapa_completo$departamento, normalizar_texto)
    coincidencias <- mapa_completo[mapa_completo$provincia_norm == provincia_norm, ]
    mapa <- mapa_completo
  }
  
  if (nrow(coincidencias) == 0) {
    sugerencias <- unique(utils::head(mapa$provincia[agrep(provincia_norm, mapa$provincia_norm, max.distance = 0.1)], 5))
    mensaje_error <- paste0("Error: No se encontro la provincia '", provincia, "'.")
    if (length(sugerencias) > 0) {
      mensaje_error <- paste0(mensaje_error, " Quiso decir una de estas?: ",
                              paste(sugerencias, collapse = ", "))
    }
    stop(mensaje_error)
  }
  
  if (!is.null(departamento_norm)) {
    coincidencias <- coincidencias[coincidencias$departamento_norm == departamento_norm, ]
  }
  
  deps_encontrados <- unique(coincidencias$departamento)
  if (length(deps_encontrados) > 1) {
    cat("\nSe encontraron provincias con el mismo nombre en multiples departamentos:\n")
    for (dep in deps_encontrados) {
      cat(sprintf("  - Departamento: %s | Provincia: %s\n", dep, provincia))
    }
    stop("Ambiguedad detectada. Por favor especifique el parametro 'departamento' para afinar la busqueda.")
  }
  
  # Disolver distritos para obtener el poligono de la provincia completa
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
