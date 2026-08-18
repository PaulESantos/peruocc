# visualize.R
# Funciones para graficar los resultados espaciales del proyecto.

library(ggplot2)
library(sf)
library(dplyr)

#' Grafica el mapa de ocurrencias sobre el polígono del distrito
#'
#' @param resultado_lista Lista de resultados devuelta por buscar_especies_distrito().
#' @param color_por Columna para clasificar los colores ("source" por defecto, o "kingdom").
#' @param guardar_mapa Lógico; si es TRUE guarda el gráfico en data/ como PNG (def: TRUE).
#' @return El objeto de gráfico ggplot.
graficar_ocurrencias <- function(resultado_lista, color_por = "source", guardar_mapa = TRUE) {
  distrito_sf <- resultado_lista$distrito_sf
  ocurrencias <- resultado_lista$ocurrencias
  resumen <- resultado_lista$resumen
  
  nombre_distrito <- resumen$distrito
  nombre_dep <- resumen$departamento
  
  # Paleta de colores estéticos
  colores_origen <- c("GBIF" = "#1f78b4", "iNaturalist" = "#33a02c")
  colores_reino <- c("Plantae" = "#2e7d32", "Animalia" = "#d32f2f", "Otros / Desconocido" = "#757575")
  
  # Crear gráfico básico
  g <- ggplot() +
    # Capa del polígono del distrito
    geom_sf(data = distrito_sf, fill = "#f9f6f0", color = "#3e2723", linewidth = 0.8)
  
  # Si hay ocurrencias, superponer los puntos
  if (!is.null(ocurrencias) && nrow(ocurrencias) > 0) {
    # Eliminar registros con coordenadas NA
    ocurrencias_clean <- ocurrencias %>% 
      filter(!is.na(decimalLongitude) & !is.na(decimalLatitude))
    
    if (nrow(ocurrencias_clean) > 0) {
      # Convertir a objeto espacial sf
      ocurrencias_sf <- sf::st_as_sf(
        ocurrencias_clean, 
        coords = c("decimalLongitude", "decimalLatitude"), 
        crs = 4326, 
        remove = FALSE
      )
      
      # Si clasificamos por reino, rellenar NAs
      if (color_por == "kingdom") {
        ocurrencias_sf <- ocurrencias_sf %>% 
          mutate(kingdom = ifelse(is.na(kingdom), "Otros / Desconocido", kingdom))
      }
      
      # Añadir puntos de ocurrencias al gráfico
      g <- g + 
        geom_sf(data = ocurrencias_sf, aes(color = .data[[color_por]]), size = 2.2, alpha = 0.75)
      
      # Asignar escalas de colores apropiadas
      if (color_por == "source") {
        g <- g + 
          scale_color_manual(values = colores_origen, name = "Base de Datos")
      } else if (color_por == "kingdom") {
        g <- g + 
          scale_color_manual(values = colores_reino, name = "Reino")
      }
    } else {
      cat("[VISUALIZACIÓN] Nota: Los registros encontrados carecen de coordenadas válidas para ser graficados.\n")
    }
  } else {
    cat("[VISUALIZACIÓN] Nota: No se encontraron registros de ocurrencias para graficar.\n")
  }
  
  # Formatear el diseño y leyendas
  g <- g +
    labs(
      title = sprintf("Ocurrencias de Biodiversidad: Distrito de %s", nombre_distrito),
      subtitle = sprintf("Departamento: %s | Total: %d registros (GBIF: %d, iNaturalist: %d)", 
                         nombre_dep, resumen$total_registros, resumen$registros_gbif, resumen$registros_inat),
      x = "Longitud",
      y = "Latitud",
      caption = sprintf("Fuente: GBIF & iNaturalist | Generado: %s | Proyección: WGS84", Sys.Date())
    ) +
    theme_minimal(base_family = "sans") +
    theme(
      plot.title = element_text(face = "bold", size = 14, color = "#212121", hjust = 0.5),
      plot.subtitle = element_text(size = 10, color = "#616161", hjust = 0.5),
      plot.caption = element_text(size = 8, color = "#9e9e9e", face = "italic"),
      panel.grid.major = element_line(color = "#e0e0e0", linetype = "dashed"),
      panel.grid.minor = element_blank(),
      panel.background = element_rect(fill = "#fdfdfd", color = NA),
      legend.position = "bottom",
      legend.box.background = element_rect(color = "#e0e0e0", fill = "white", linewidth = 0.5),
      legend.key = element_blank(),
      axis.text = element_text(size = 8, color = "#757575"),
      axis.title = element_text(size = 9, color = "#424242")
    )
  
  # Guardar el gráfico si está solicitado y hay datos
  if (guardar_mapa) {
    dir.create("results", recursive = TRUE, showWarnings = FALSE)
    
    dist_clean <- gsub(" ", "_", tolower(normalizar_texto(nombre_distrito)))
    nombre_img <- sprintf("results/mapa_%s_%s_%s.png", dist_clean, color_por, format(Sys.time(), tz = "UTC", "%Y%m%dT%H%M%SZ"))
    
    tryCatch({
      ggsave(nombre_img, plot = g, width = 8, height = 7, dpi = 300, bg = "white")
      cat(sprintf("[VISUALIZACIÓN] Mapa estático guardado en: '%s'\n", nombre_img))
    }, error = function(e) {
      cat("[VISUALIZACIÓN] Error al guardar el mapa en archivo: ", e$message, "\n")
    })
  }
  
  return(g)
}
