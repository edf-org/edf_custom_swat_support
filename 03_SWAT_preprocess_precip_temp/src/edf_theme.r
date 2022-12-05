
library(ggplot2)


#' using guide from:
#' https://www.statworx.com/de/blog/custom-themes-in-ggplot2/

#' Function to modify ggplot theme_minimal() to EDF styling
#' 
theme_edf <- function(base_size = 11,
                      base_family = "",
                      base_line_size = base_size / 170,
                      base_rect_size = base_size / 170){
  theme_minimal(base_size = base_size, 
                base_family = base_family,
                base_line_size = base_line_size) %+replace%
    theme(plot.title = element_text(size = 16, margin=margin(0, 0, 10, 0), face="bold", hjust=0, color="#253D86"),
            plot.subtitle = element_text(size = 12, margin=margin(0, 0, 10, 0), color="#253D86", hjust=0, face="plain"),
            plot.caption = element_text(size = 8,  hjust=0, margin=margin(20, 0, 0, 0), color="#59595C"), 
            legend.text = element_text(size = 9, color="#59595C"), 
            legend.title = element_text(size = 10, face="bold", color="#59595C"),
            axis.title = element_text(size = 10, face="plain", color="#59595C"),
      complete = TRUE
    )
}


#' Custom colour palette functions
#' using guide from:
#' https://drsimonj.svbtle.com/creating-corporate-colour-palettes-for-ggplot2

# EDF corporate colors
edf_colors <- c(
    `blue`          = "#253D86", 
    `yellow-green`  = "#C8DA2C",
    `cyan`          = "#029EDA",
    `green`         = "#00985F",
    `gray`          = "#59595C",
    `grey`          = "#59595C",
    `gold`          = "#C79900",
    `pink`          = "#F39EBC",
    `olive`         = "#726E20",
    `blue-grey`     = "#44697D",
    `yellow`        = "#EBB700",
    `orange`        = "#E17000",
    `lavender`      = "#8E68AD",
    `brown`         = "#512B1B",
    `forest-green`  = "#1D5D43",
    `black`         = "#4A3C31",
    `alarm-red`     = "#DF1D37",
    `fresh-green`   = "#049B49",
    `brick-red`     = "#983322",
    `teal`          = "#6FC7B2"
)



#' Function to extract EDF colors as hex codes
#'
#' @param ... Character names of edf_colors 
#'
edf_cols <- function(...) {
  cols <- c(...)

  if (is.null(cols))
    return (edf_colors)

  edf_colors[cols]
}

# EDF palettes
edf_palettes <- list(
#   `main`  = edf_cols("blue", "fresh-green", "yellow"),
  `main`  = edf_cols("green", "blue", "cyan", "yellow-green"),

  `cool`  = edf_cols("teal", "lavender", "blue-grey"),

  `bright`= edf_cols("yellow-green", "cyan", "green"),

  `hot`= edf_cols("yellow", "orange", "brick-red"), 

  `oceans` = edf_cols("teal", "blue", "cyan", "green"),

  `health` = edf_cols("cyan", "fresh-green", "orange", "yellow"),

  `climate` = edf_cols("orange", "brick-red", "grey", "yellow"),

  `ecosystem` = edf_cols("fresh-green", "brown", "blue", "yellow-green"),

  `energy` = edf_cols("orange", "blue-grey", "forest-green", "yellow"),

  `mixed` = edf_cols("blue-grey", "fresh-green", "yellow", "orange", "brick-red", "gold", "pink", "lavender"),

  `dark`  = edf_cols("forest-green", "grey", "blue-grey", "black", "brown")
)



#' Return function to interpolate an EDF color palette
#'
#' @param palette Character name of palette in drsimonj_palettes
#' @param reverse Boolean indicating whether the palette should be reversed
#' @param ... Additional arguments to pass to colorRampPalette()
#'
edf_pal <- function(palette = "main", reverse = FALSE, ...) {
  pal <- edf_palettes[[palette]]

  if (reverse) pal <- rev(pal)

  colorRampPalette(pal, ...)
}



#' Color scale constructor for EDF colors
#'
#' @param palette Character name of palette in edf_palettes
#' @param discrete Boolean indicating whether color aesthetic is discrete or not
#' @param reverse Boolean indicating whether the palette should be reversed
#' @param ... Additional arguments passed to discrete_scale() or
#'            scale_color_gradientn(), used respectively when discrete is TRUE or FALSE
#'
scale_color_edf <- function(palette = "main", discrete = TRUE, reverse = FALSE, ...) {
  pal <- edf_pal(palette = palette, reverse = reverse)

  if (discrete) {
    discrete_scale("colour", paste0("edf_", palette), palette = pal, ...)
  } else {
    scale_color_gradientn(colours = pal(256), ...)
  }
}

#' Fill scale constructor for EDF colors
#'
#' @param palette Character name of palette in edf_palettes
#' @param discrete Boolean indicating whether color aesthetic is discrete or not
#' @param reverse Boolean indicating whether the palette should be reversed
#' @param ... Additional arguments passed to discrete_scale() or
#'            scale_fill_gradientn(), used respectively when discrete is TRUE or FALSE
#'
scale_fill_edf <- function(palette = "main", discrete = TRUE, reverse = FALSE, ...) {
  pal <- edf_pal(palette = palette, reverse = reverse)

  if (discrete) {
    discrete_scale("fill", paste0("edf_", palette), palette = pal, ...)
  } else {
    scale_fill_gradientn(colours = pal(256), ...)
  }
}


#' Display all EDF colors in a simple chart
#'
#' @param palette Character name of palette in edf_palettes
#'                if missing all colors are shown

show_colors <- function(palette){
  
  if(missing(palette)){
    cols <- edf_colors
    palette = "all colors"
  } else {
    cols <- edf_palettes[[palette]]
  }
  
  color_chart <- tibble(name = names(cols), value = rep(1, length(names(cols))))
  
  ggplot(color_chart, aes(name, value, fill = name)) +
    geom_bar(stat = "identity") +
    coord_flip() +
    scale_fill_manual(values = edf_colors, guide = FALSE) +
    theme(axis.text.x = element_blank()) +
    labs(title = "EDF colors", subtitle = paste0("palette: ", palette), x = "", y = "")
}