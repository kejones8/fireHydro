#' @title Converts EDEN water surface data between feet NGVD29 and centimeters relative to soil surface 
#'
#' @description Easily convert between two sets of common EDEN water surface units and datums (cm depth and ft NGVD29). This function makes for easy compatibility bewtween EDEN data (cm depth) and EverForecast output (ft. NGVD29). The conversion relies on the EDEN DEM and a raster layer with NAVD88-NGVD29 conversion factors, built by interpolating between gauges in the EDEN network (https://sofia.usgs.gov/eden/stationlist.php). Both layers are available in fireHydro.
#' 
#' @param EDENdata A raster or rasterstack of EDEN data, such as that returned by `getEDEN()`
#' @param to unit/datum to convert EDENdata to. Acceptable inputs are "ft_NGVD29" or "cm_soil"
#' 
#' @return list \code{getEDEN} returns a list with two elements: (1) the date used, and (2) a spatial object with water levels (centimeters relative to soil surface) in the EDEN grid.
#' 
#' 
#' @examples
#' 
#' \dontrun{
#' edenDat <- getEDEN()
#' plot(edenDat$data[[1]])
#' 
#' edenDat$data <- convertEDEN(EDENdata = edenDat$data, to = "ft_NGVD29")
#' plot(edenDat$data[[1]])
#' }
#' 
#' @importFrom raster raster
#' @importFrom raster resample
#' @importFrom raster overlay
#' @importFrom raster projectRaster
#' @importFrom raster extent
#' 
#' @export



convertEDEN <- function(EDENdata,  # the 'data' part of an EDEN date/data list
                        to = "ft_NGVD29" # "ft_NGVD29" or "cm_soil"
) {
  ### accommodate accidental EDENlist input
  inputType <- "data" # flag for whether EDENdata object is data or EDEN list
  if (is.list(EDENdata)) {
    cat("EDENdata looks like a list, rather than a raster/stack.\n")
    if(all(grepl(x = names(EDENdata), pattern = "data|date"))) {
      EDENdate <- EDENdata$date
      EDENdata <- EDENdata$data
      inputType    <- "list"
    } else {
      stop("EDENdata input does not look like the output of getEDEN(). Please review documentation: ?convertEDEN")
    }
  }
  
  ### converts EDEN data from cm depth (w.r.t soil surface) to ft. NGVD29
  dem_eden   <- raster::raster(system.file("extdata/edenDEM.grd", package = "fireHydro")) # DEM used in eden data (meters NAVD88)
  dem_ngvd   <- (dem_eden * 3.2808) + raster::raster(system.file("extdata/convertNGVD.grd", package = "EvergladesEBM"))
  
  if(!(raster::extent(dem_ngvd) == raster::extent(EDENdata))) { # crop/mask to DEM if the extents differ
    EDENdata <- raster::resample(EDENdata, dem_ngvd)
  }
  
  if (to %in% "ft_NGVD29") {
    newdata <- raster::overlay(EDENdata, # units = cm wrt soil
                       dem_ngvd,    # units = feet NGVD
                       fun=function(r1, r2){return((r1  * 0.0328084) # feet rel. to soil surface  
                                                   + r2)})
  } else if (to %in% "cm_soil") { # convert from ft NGVD to cm w.r.t. soil surface
    newdata <- raster::overlay(EDENdata, # units = cm wrt soil
                       dem_ngvd,    # units = feet NGVD
                       fun=function(r1, r2){return((r1 - r2) # feet rel. to soil surface  
                                                   / 0.0328084)})
  }
  names(newdata) <- names(EDENdata)
  EDEN_out       <- newdata
  
  ### if an EDEN list was input, return an EDEN list
  if (grepl(x = inputType, pattern = "list")) {
    EDEN_out <- list(date = EDENdate, data = EDEN_out)
  }
  return(EDEN_out)
}
