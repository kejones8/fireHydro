#' @title Generate fire-hydro shapefile
#'
#' @description Generates shapefile showing fire potential. Presently only works on the SFNRC network (for EDEN data access)
#' 
#' @usage getFireHydro(EDEN_date, 
#'     output_shapefile = NULL,
#'     waterLevelExport = NULL,
#'     fireSpreadExport = NULL,
#'     csvExport = NULL,
#'     EDEN_GIS_directory = "detect",
#'     vegetation_shp = fireHydro::vegetation,
#'     BICY_EVER_PlanningUnits_shp = fireHydro::BICY_EVER_PlanningUnits,
#'     returnShp = TRUE,
#'     figureWidth = 6.5,
#'     figureHeight = 4,
#'     ggBaseSize = 12,
#'     burnHist = TRUE,
#'     burnData = list(fireHydro::fire182, fireHydro::fire192, fireHydro::fire_2020))
#' 
#' @param EDEN_date EDEN date to be used for water levels. Should be a character string, e.g., "20181018"
#' @param output_shapefile file address for shapefile output. Driver is inferred from file extnesion, so may not be correct. In this case, user can export shapefile after generating the sf object through \code{getFireHydro()}.
#' @param waterLevelExport NULL or a character vector specifying the file address/name used for exporting an image file of water level categories (e.g., /home/waterLevels.pdf).
#' @param fireSpreadExport NULL or a character vector specifying the file address/name used for exporting an image file of fire spread risk (e.g., /home/fireSpreadRisk.pdf).
#' @param csvExport If an exported .csv file of the output is desired, include a file addess/name here (e.g., "fireHydroOutput.csv")
#' @param EDEN_GIS_directory The source for EDEN data. Can be an \code{sf} object already in the working environment (such as the data output from \code{\link[fireHydro]{getEDEN}}) or, for users with access to the SFNRC's physical drive, the default value (\code{"detect"}) will identify the parent directory where EDEN water level data are located ("/opt/physical/gis/eden/" on linux; "Y:/gis/eden/" on Windows). This can alternatively be the specific address of a shapefile of EDEN data or a character string naming an object in the working environment, such as that generated from getEDEN().
#' @param vegetation_shp shapefile of vegetation data in Big Cypress and Everglades
#' @param BICY_EVER_PlanningUnits_shp shapefile of polygons representing Big Cypress and Everglades planning units
#' @param returnShp TRUE/FALSE determinant of whether output is returned to the working environment
#' @param figureWidth width of output figure, in inches
#' @param figureHeight height of output figure, in inches 
#' @param ggBaseSize base_size argument passed to ggplot theme. 
#' @param burnHist logical; if FALSE, fire spread risk is a binary variable (high/low); if TRUE, fire history during the preceding three years is used to split fire spread risk into a gradient of risk: High = high current fire spread risk and no burn history in past 3 years; Moderately High = high current fire spread risk and burned three years ago; Moderate = high current fire spread risk and burned two years ago; Moderately Low = high current fire spread risk and burned in the past year; Low = low current fire spread risk (regardless of burn history)
#' @param burnData list with three elements: simple feature polygon files with burn history data. Data must be in ascending chronological order; this will be used to parse areas of high fire spread risk into finer categories.
#' @return sf 
#' 
#' 
#' @examples
#' 
#' \dontrun{
#' 
#' # produce maps with the most recent EDEN data
#' EDENdat <- getEDEN()
#' fireDat <- getFireHydro(EDEN_date = EDENdat$date, 
#'      EDEN_GIS_directory = EDENdat$data,
#'      fireSpreadExport = paste0("fireRisk_", EDENdat$date, ".png"), 
#'      waterLevelExport = paste0("waterLevels_", EDENdat$date, ".png"))
#' 
#' ### some more examples:
#' getFireHydro(EDEN_date = "20181018",
#'      fireSpreadExport = "fireRisk.png", waterLevelExport = "waterLevels.png")
#' 
#' # save output in multiple file types (and exclude burn history)
#' getFireHydro(EDEN_date = "20181018", 
#'      burnHist = FALSE,
#'      fireSpreadExport = c("fireRisk.png", "fireRisk.pdf"))
#'      
#' # incorportate burn history to fire spread risk maps
#' getFireHydro(EDEN_date = "20181018", 
#'      fireSpreadExport = c("fireRisk.png", "fireRisk.pdf"))
#' 
#' }
#' 
#' @importFrom utils write.csv
#' @importFrom sf st_read
#' @importFrom sf st_transform
#' @importFrom sf st_intersection
#' @importFrom sf st_write
#' @importFrom sf st_set_geometry
#' @importFrom sf st_buffer
#' @importFrom sf st_area
#' @importFrom dplyr group_by
#' @importFrom dplyr summarize
#' @importFrom rgdal setCPLConfigOption
#' @importFrom rgdal writeGDAL
#' @importFrom ggplot2 ggplot
#' @importFrom ggplot2 geom_sf
#' @importFrom ggplot2 aes
#' @importFrom ggplot2 ggsave
#' @importFrom ggplot2 theme_bw
#' @importFrom ggplot2 labs
#' @importFrom ggplot2 scale_fill_brewer
#' @importFrom ggplot2 scale_colour_brewer
#' 
#' @export


getFireHydro_kj <- function(EDEN_date,eden_data,avg_erc, 
                         output_shapefile = NULL, 
                         waterLevelExport = NULL,
                         fireSpreadExport = NULL,
                         csvExport = NULL, 
                         EDEN_GIS_directory = "detect",
                         #vegetation_shp = fireHydro::vegetation,
                         #BICY_EVER_PlanningUnits_shp = fireHydro::BICY_EVER_PlanningUnits,
                         #BICY_EVER_PlanningUnits_shp = fireHydro::diss_0322_veg_ever_bicy,
                         returnShp = TRUE, figureWidth = 6.5, figureHeight = 4, 
                         ggBaseSize = 12,
                         burnHist = TRUE,
                         burnData = list(fireHydro::fire182, fireHydro::fire192, fireHydro::fire_2020)) {
  ### TODO:
  ### supply example EDEN data for testing
  ### avoid warnings from st_intersect http://r-sig-geo.2731867.n2.nabble.com/Warning-in-st-intersection-td7591290.html https://github.com/r-spatial/sf/issues/406
  ### un-pack piped statements
  ### user specifies what's displayed in the output?
  ### what's up with the shapefiles that used to be exported - are they useful? should they have export options? 
  feetToCm <- function(x) {
    outDat <- x * 12 * 2.54 # Fire Cache uses three sig figs for this unit conversion
    outDat
  }

  ###NEED TO RUN MAIN - THIS CREATES EDEN TEST AREA
  eden_epa_needproj<-eden_poly
  
  #just putting this in here to get CRS correct
  load("data\\BICY_EVER_PlanningUnits.RData")
  utm_crs<-st_crs(BICY_EVER_PlanningUnits)
  
  
  #BICY_EVER_PlanningUnits_shp<-fireHydro::BICY_EVER_PlanningUnits
  #load("data\\BICY_EVER_PlanningUnits.RData")
  #BICY_EVER_PlanningUnits_shp<-BICY_EVER_PlanningUnits
  #planningUnits_shp <- sf::st_union(BICY_EVER_PlanningUnits_shp)
  #st_write(planningUnits_shp,"tests\\extent_plan_units.shp")
  
  #still segmented by management unit
  BICY_EVER_PlanningUnits_shp<-st_read("C:\\Users\\thebrain\\Dropbox\\LCLab\\Everglades\\data\\SouthFlorida_FMUs (1)\\SouthFlorida_FMUs.shp")
  
  #dissolved full boundary extent
  planningUnits_shp<-st_read("C:\\Users\\thebrain\\Dropbox\\LCLab\\Everglades\\data\\diss_manag_units.shp")
  #EDEN_date2    <- format(x = strptime(x = as.character(EDEN_date), format = "%Y%m%d"), "%d %b %Y")
  
  ### argument to auto-generate output 
  # output_shapefile <- paste0("analysis/outcomes/fireRisk_area_", EDEN_date, ".csv")
  # outputCsv  <- paste0("analysis/outcomes/fireRisk_area_", EDEN_date, ".csv")
  eden_epa<-st_transform(eden_epa_needproj,utm_crs)
  trans_BICY_EVER_PlanningUnits_shp<-st_transform(BICY_EVER_PlanningUnits_shp,utm_crs)
  trans_planningUnits_shp<-st_transform(planningUnits_shp,utm_crs)
  
  # EDEN_GIS_directory_main <- gsub(x = EDEN_GIS_directory, pattern = "\\$.*", replacement = "")
  # get(paste0(EDEN_GIS_directory_main, "$", gsub(x = EDEN_GIS_directory, pattern = ".*\\$", replacement = "")))
  
  ### adjust EDEN directory for operating system
  # if(!"character" %in% class(EDEN_GIS_directory)) stop("EDEN_GIS_DIRECTORY argument needs to be a character vector (e.g., an object in the working environment ('dat1'), a shapefile address ('dat1.shp'), a directory (e.g., 'Y:/gis/eden/') or the word 'detect'. )")
  
  # if ((length(EDEN_GIS_directory) == 1) && (class(EDEN_GIS_directory)[1] %in% "character") && (EDEN_GIS_directory[1] == "detect")) {
  #   switch(Sys.info()[['sysname']],
  #          Windows= {EDEN_GIS_directory <- "Y:/gis/eden/"},
  #          Linux  = {EDEN_GIS_directory <- "/opt/physical/gis/eden/"},
  #          Darwin = {stop("EDEN data parent directory address is not automatically identified for Mac OS.")})
  #   eden_epa               <- sf::st_read(paste0(EDEN_GIS_directory, substr(EDEN_date, 1, 4), "/eden_epa", EDEN_date, ".shp"))
  # } else if ((length(EDEN_GIS_directory) == 1) && (class(EDEN_GIS_directory)[1] %in% "character") && (grepl(x = EDEN_GIS_directory, pattern = "shp$"))) {
  #   eden_epa               <- sf::st_read(EDEN_GIS_directory)
  #   # } else if (exists(EDEN_GIS_directory_main)) { # gsub(x = "a$data", pattern = "\\$.*", replacement = "")
  # } else if ("sf" %in% class(EDEN_GIS_directory)) {
  #   # if ("sf" %in% class(get(EDEN_GIS_directory)) || "sf" %in% class(EDEN_GIS_directory)) { # if EDEN data are already a SIMPLE FEATURE object in workspace
  #     eden_epa   <- EDEN_GIS_directory
  #   #} else  if (any(unlist(sapply(X = get(EDEN_GIS_directory_main), FUN = class)) %in% "sf")) { # if EDEN data are already a SIMPLE FEATURE object in workspace
  #   #   eden_epa   <- get(EDEN_GIS_directory_main)$get(gsub(x = EDEN_GIS_directory, pattern = ".*\\$", replacement = "")) # gsub(x = "a$data", pattern = ".*\\$", replacement = "")
  #   # }
  # } else {
  #   stop("EDEN_GIS_DIRECTORY argument appears to be invalid. It is not an sf object in current working environment")
  # }
  

  ### use table of vegetation categories and their thresholds (above which, a pixel is no longer low risk)
  ### table names must be "veg" and "threshold"
  ### veg names must match exactly the categories in vegetation map. Can use regex commands to assign 
  ### one threshold to multiple categories (e.g., "cat1|cat2")
  ### units must be feet. 
  # vegTbl <- data.frame(veg = c("Tall Continuous Grass",
  #                              "Short Continuous Grass",
  #                              "Pine Forest",
  #                              "Pine Savannah",
  #                              "Short Sparse Grass",
  #                              "Shrub",
  #                              "Hammock/Tree Island|Coastal Forest",
  #                              "Brazilian Pepper/HID", 
  #                              "Beach dune"),
  #                      threshold = c(3.6, 0, 2.6, 1.6, 0, -0.6, -0.6, -1, 2.6))
  
  veg_fuel<-c("GR1","GR3","GR8","GS3","NB1","NB3","NB8","NB9","SH6","TL2","TL4")
  veg_risk<-c(4,3,2,5,9,8,9,9,1,7,6)
  vegTbl <-data.frame(veg_fuel=veg_fuel,veg_risk=veg_risk)
  
  
  
  depthDivisions <- c(-Inf, -1.1, -0.5, 0, 0.5, 1.5, 2.5, 3.5, Inf) # number of columns in fire cache table
  noDivisions    <- length(depthDivisions) - 1
  ascendingSeq  <- seq(1:noDivisions)
  ### WaterLevel: lower where water depth is higher. 
  ### veg map polygon is high risk where vegmap$WaterLevel > vegTbl$WaterLevel (*not* greater than or equal to)
  #vegTbl$WaterLevel    <- descendingSeq[findInterval(feetToCm(vegTbl$threshold), feetToCm(depthDivisions))]
  
  ### this is tough to automate. Should reflect depthDivisions
  # waterLevelLabels <- c("0" = "Above Surface: >3.6 ft",         
  #                       "1" = "Above Surface: 2.6-3.6 ft",   
  #                       "2" = "Above Surface: 1.6-2.6 ft",    
  #                       "3" = "Above Surface: 0.6-1.6 ft",    
  #                       "4" = "Above Surface: 0-0.6 ft", 
  #                       "5" = "Below Surface: -0.6-0 ft", 
  #                       "6" = "Below Surface: -1 to -0.6 ft", 
  #                       "7" = "Below Surface: < -1 ft" )
  
  #changed this to be reverse intervals that match risk table provided by NPS
  #water level label is actually risk level
  waterLevelLabels <- c("8" = "Above Surface: >3.6 ft",
                        "7" = "Above Surface: 2.6-3.5 ft",
                        "6" = "Above Surface: 1.6-2.5 ft",
                        "5" = "Above Surface: 0.6-1.5 ft",
                        "4" = "Above Surface: 0.1-0.5 ft",
                        "3" = "Below Surface: -0.6-0 ft",
                        "2" = "Below Surface: -1 to -0.6 ft",
                        "1" = "Below Surface: < -1 ft" )
  
  waterLevelColors <- c("8" = "cornflowerblue", "7" = "lightseagreen", "6" = "green4", 
                        "5" = "yellow3",        "4" = "yellow1",       "3" = "orange",  
                        "2" = "orangered3",     "1" = "firebrick")
  
  
  
  ###################
  ################### Trying to eliminate this section
  ### Read EDEN EPA hydro data                    
  # ye olde version (pre-20190222): eden_epa$WaterLevel    <- c(6, 5, 4, 3, 2, 1, 0)[findInterval(eden_epa$WaterDepth, c(-Inf, -30.48, -18.288, 0, 48.768, 91.44, 121.92, Inf))]   # Rank water depth
  # ye olde version (pre 20200731): eden_epa$WaterLevel    <- c(7, 6, 5, 4, 3, 2, 1, 0)[findInterval(eden_epa$WaterDepth, feetToCm(c(-Inf, -1, -0.6, 0, 0.6, 1.6, 2.6, 3.6, Inf)))]   # Rank water depth
  #eden_epa$WaterDepth_ft <- feetToCm(eden_epa$WaterDepth)
  #water level is water risk value from above water level labels
  eden_epa$WaterLevel    <- ascendingSeq[findInterval(eden_epa$WaterDepth, feetToCm(depthDivisions))]   # Rank water depth, depth divisions are provided in feet, but water levels in cm (DEM fed in to getEDEN in meters & spit out in centimeters)
  eden_epa$WaterDepth_ft<-round(eden_epa$WaterDepth/30.48,5) #now, convert it to feet, so i can look at it relative to depth divisions (input in tablein feet)
  ### h(g(f(x))) = f(x) %>%  g() %>% h() = a <- f(x); b <- g(a);   h(b)
  eden_epaGroup          <- dplyr::summarize(.data = dplyr::group_by(.data = eden_epa, WaterLevel), .groups = 'drop',
                                             avg_depth_ft=mean(WaterDepth_ft))
                                             #sum = sum(WaterDepth))                         # Dissovle grid to minize the file size
  eden_epaGroupPrj       <- sf::st_transform(eden_epaGroup, utm_crs)                                   # Reproject dissolved grid to park boundary
  eden_epa_reclass       <- eden_epaGroupPrj[,c("WaterLevel","avg_depth_ft")]
  
  write_sf(eden_epa_reclass,"eden_epa_reclass_20180410.shp",overwrite=TRUE)
  
  withCallingHandlers( # takes a long time
    eden_epa_reclass <- sf::st_intersection(eden_epa_reclass, trans_planningUnits_shp), warning = fireHydro::intersectionWarningHandler)                                 # Clip the EDEN EPA hydro using the park boundary
  ### Combine EDEN EPA hydro and fuel types
  
  #not sure why this couldn't be done with load...
  #vegetation_shp<-read_sf("data\\diss_veg_ever_bicy.shp") #when trying to run WHOLE area veg
  vegetation_shp<-read_sf("data\\diss_veg_ever_bicy.shp")
  
  
  veg_shp_trans       <- sf::st_transform(vegetation_shp, sf::st_crs(utm_crs))

  vegetation_reclass <- veg_shp_trans[, c("L9_veg")]     
  colnames(vegetation_reclass)      <- c("Veg_Cat","geometry")
  
  

  #could load these as already created files
  veg_reclass<-merge(vegetation_reclass,vegTbl,by.x="Veg_Cat",by.y="veg_fuel")
  
  #####need parallelize intersection below for quicker running#####
  #could still make veg layers prior w/ valid/buf, then intersect..
  #what do i need to consider if adding paralleliztion to the package for it to run in the future
  #on other machines?
  
 
  withCallingHandlers(
    #eden_epaNveg        <- sf::st_intersection(sf::st_buffer(veg_reclass,0), eden_epa_reclass), warning = fireHydro::intersectionWarningHandler)
    eden_epaNveg        <- sf::st_intersection(sf::st_buffer(veg_reclass,0), eden_epa_reclass), warning = fireHydro::intersectionWarningHandler)

    eden_epaNveg<-read_sf("par_output_03102022.shp")
    names(eden_epaNveg)[names(eden_epaNveg) == 'veg_rsk'] <- 'veg_risk'
    names(eden_epaNveg)[names(eden_epaNveg) == 'WatrLvl'] <- 'WaterLevel'

    #eden_epaNveg<-didthiswork_nosimp_edenlatenightwl
  
    eden_epaNveg$rval_wat_veg<-eden_epaNveg$veg_risk*eden_epaNveg$WaterLevel
    
    #eden_epaNveg$WF_Use <- riskNames[length(riskNames)] #just assigns low risk?
  
  #Implenting a multiplicative approach based on: 
  
  # 1. Veg/Fuel Type 2. Water Level  3. ERC val
  
  #erc_val<-15 #working ERC value, this will be an input from the get_erc_data function eventually
  
  eden_epaNveg$avg_ERC<-avg_erc
  #assign ERC risk val 1-5
  erc_divisions <- c(-Inf,8, 22, 29, 33,Inf)
  num_erc_Divisions    <- length(erc_divisions)-1
  ascending_erc_Seq  <- rev(1:num_erc_Divisions)
  eden_epaNveg$erc_risk_val    <- ascending_erc_Seq[findInterval(eden_epaNveg$avg_ERC, erc_divisions)]   # Rank water depth
  
  
  #final calc
  eden_epaNveg$riskNum<-eden_epaNveg$veg_risk*eden_epaNveg$WaterLevel*eden_epaNveg$erc_risk_val
  
  ### Fire Spread Risk category names
  riskNames   <- c("High", "Moderately High", "Moderate", "Moderately Low", "Low")
  risk_vals<-c(5,4,3,2,1)
  
  riskTbl <-data.frame(risk_names=riskNames,RiskLevel=risk_vals)
  
  
  risk_int<- c(-Inf,16,32,56,109,Inf)
  riskDivisions    <- length(risk_int)-1
  riskSeq  <- rev(1:riskDivisions)
  eden_epaNveg$RiskLevel    <- riskSeq[findInterval(eden_epaNveg$riskNum, risk_int)]   
  
  eden_epaNveg<-merge(eden_epaNveg,riskTbl,by="RiskLevel") 
  
  
  ###################
  ###################

  # ### alternate version (large object)
  # ### add vegetation_shp$Veg_Cat to eden_epa
  # newEDEN <- sf::st_transform(eden_epa, sf::st_crs(planningUnits_shp))
  # ### clip EDEN data to match planning units
  # withCallingHandlers( # takes hours. Not workable.
  #   newEDEN <- sf::st_intersection(newEDEN, planningUnits_shp), warning = fireHydro::intersectionWarningHandler)
  # ### this is supposed to do a spatial join to add a column, but takes forever
  # newDat <- sf::st_join(y = newEDEN, x = vegetation_shp[, "Veg_Cat"])
  # ###
    

  
  ####Here is where I think I need to overhaul the logic
   
  # 
  # 
  # if (any(grepl(pattern = paste0(vegTbl$veg, collapse = "|"), x = unique(eden_epaNveg$Veg_Cat)))) {
  #   missingCats <- paste0(unique(eden_epaNveg$Veg_Cat)[!grepl(pattern = paste0(vegTbl$veg, collapse = "|"), x = unique(eden_epaNveg$Veg_Cat))], collapse = ",")
  #   message("Vegetation categories observed in vegetation map without corresponding water level threshold: ", missingCats)
  # }
  # ### use table to assign high risk values
  # for (i in 1:nrow(vegTbl)) {
  #   ### counterintuitive: if "WaterLevel" variable is greater than vegTbl$WaterLevel, observed water depth is lower than threshold.
  #   eden_epaNveg$WF_Use[grepl(x = eden_epaNveg$Veg_Cat, pattern = vegTbl$veg[i]) & 
  #                         (eden_epaNveg$WaterLevel         > vegTbl$WaterLevel[i])] <- riskNames[1]
  # }
  
  ### approach used prior to 20200731
  # eden_epaNveg$WF_Use[grepl(x = eden_epaNveg$Veg_Cat, pattern = "Tall Continuous Grass") & 
  #                       (eden_epaNveg$WaterLevel         > 0)] <- riskNames[1]
  # eden_epaNveg$WF_Use[grepl(x = eden_epaNveg$Veg_Cat, pattern = "Short Continuous Grass") & 
  #                       (eden_epaNveg$WaterLevel         > 4)] <- riskNames[1]
  # eden_epaNveg$WF_Use[grepl(x = eden_epaNveg$Veg_Cat, pattern = "Pine Forest") & 
  #                       (eden_epaNveg$WaterLevel         > 1)] <- riskNames[1]
  # eden_epaNveg$WF_Use[grepl(x = eden_epaNveg$Veg_Cat, pattern = "Pine Savannah") & 
  #                       (eden_epaNveg$WaterLevel         > 2)] <- riskNames[1]
  # eden_epaNveg$WF_Use[grepl(x = eden_epaNveg$Veg_Cat, pattern = "Short Sparse Grass") & 
  #                       (eden_epaNveg$WaterLevel         > 4)] <- riskNames[1]
  # eden_epaNveg$WF_Use[grepl(x = eden_epaNveg$Veg_Cat, pattern = "Shrub") & 
  #                       (eden_epaNveg$WaterLevel         > 6)] <- riskNames[1]
  # eden_epaNveg$WF_Use[grepl(x = eden_epaNveg$Veg_Cat, pattern = "Hammock/Tree Island|Coastal Forest") & 
  #                       (eden_epaNveg$WaterLevel         > 5)] <- riskNames[1]
  # eden_epaNveg$WF_Use[grepl(x = eden_epaNveg$Veg_Cat, pattern = "Brazilian Pepper/HID") & 
  #                       (eden_epaNveg$WaterLevel         > 6)] <- riskNames[1]
  
  ### version prior to change on 20200403, mistakenly treats "WaterLevel" variable as if it were "WaterDepth", regex errors in hammock areas
    # eden_epaNveg$WF_Use <- ifelse((eden_epaNveg$Veg_Cat == "Tall Continuous Grass") & (eden_epaNveg$WaterLevel <= feetToCm(4)), riskNames[1], 
    #                             ifelse((eden_epaNveg$Veg_Cat == "Short Continuous Grass") & (eden_epaNveg$WaterLevel <= feetToCm(0)), riskNames[1],
    #                                    ifelse((eden_epaNveg$Veg_Cat == "Pine Forest") & (eden_epaNveg$WaterLevel <= feetToCm(3)), riskNames[1],
    #                                           ifelse((eden_epaNveg$Veg_Cat == "Pine Savannah") & (eden_epaNveg$WaterLevel <= feetToCm(1.6)), riskNames[1],
    #                                                  ifelse((eden_epaNveg$Veg_Cat == "Short Sparse Grass") & (eden_epaNveg$WaterLevel <= 0), riskNames[1], 
    #                                                         ifelse((eden_epaNveg$Veg_Cat == "Shrub") & (eden_epaNveg$WaterLevel <= feetToCm(-1)), riskNames[1], 
    #                                                                ifelse((eden_epaNveg$Veg_Cat == "Hammock/Tree Island|Coastal Forest") & (eden_epaNveg$WaterLevel <= feetToCm(-0.6)), riskNames[1],
    #                                                                       ifelse((eden_epaNveg$Veg_Cat == "Brazilian Pepper/HID") & (eden_epaNveg$WaterLevel <= feetToCm(-1)), riskNames[1],
    #                                                                              riskNames[length(riskNames)])))))))) # changed  waterLevel threshold from 4 to 5 on 20190222
    # 
  # eden_epaNveg$WF_Use <-ifelse(eden_epaNveg$FuelType == 5 & eden_epaNveg$WaterLevel >= 0, riskNames[1], # tall continuous grass, pine forest
  #                              ifelse(eden_epaNveg$FuelType == 4 & eden_epaNveg$WaterLevel >= 1, riskNames[1],
  #                                     ifelse(eden_epaNveg$FuelType == 3 & eden_epaNveg$WaterLevel >= 5, riskNames[1], # changed  waterLevel threshold from 4 to 5 on 20190222
  #                                            ifelse(eden_epaNveg$FuelType == 2 & eden_epaNveg$WaterLevel > 5, riskNames[1], riskNames[length(riskNames)])))) # changed  waterLevel threshold from 4 to 5 on 20190222

  
  #not sure what this represents, ask Jill
  #currently doesn't run because I took out $WF_Use
  #eden_epaNveg$RX_Use <-ifelse(eden_epaNveg$WF_Use == riskNames[1], "High Fuel Availability", "Low Fuel Availability")
  
  

 ### Combine fireRisk data with planning units
  # st_intersection warning: attribute variables are assumed to be spatially constant throughout all geometries
  withCallingHandlers( # takes a long time
    eden_epaNveg_planningUnits              <- sf::st_intersection(eden_epaNveg, trans_planningUnits_shp[, c("Unit_Code", "FMU_Name")]), warning = fireHydro::intersectionWarningHandler)
  
  ### make sure this works if not all levels occur in the data
  # eden_epaNveg_planningUnits$WL_des         <- plyr::revalue(as.factor(eden_epaNveg_planningUnits$WaterLevel), waterLevelLabels)
  # eden_epaNveg_planningUnits$WL_des2         <- as.factor(eden_epaNveg_planningUnits$WaterLevel)
  # levels(eden_epaNveg_planningUnits$WL_des2) <- waterLevelLabels[names(waterLevelLabels) %in% unique(eden_epaNveg_planningUnits$WaterLevel)]
  # all.equal(eden_epaNveg_planningUnits$WL_des, eden_epaNveg_planningUnits$WL_des2)
  # head(eden_epaNveg_planningUnits[, c("WL_des", "WL_des2")])
  
  eden_epaNveg_planningUnits$WL_des         <- as.factor(eden_epaNveg_planningUnits$WaterLevel)
  levels(eden_epaNveg_planningUnits$WL_des) <- waterLevelLabels[names(waterLevelLabels) %in% unique(eden_epaNveg_planningUnits$WaterLevel)]
  
  eden_epaNveg_planningUnits$WL_des_colors         <- as.factor(eden_epaNveg_planningUnits$WaterLevel)
  levels(eden_epaNveg_planningUnits$WL_des_colors) <- waterLevelLabels[names(waterLevelLabels) %in% unique(eden_epaNveg_planningUnits$WaterLevel)]
  
  ### re-written in base R on 20180814:
  # eden_epaNveg_planningUnits$WL_des         <- plyr::revalue(as.factor(eden_epaNveg_planningUnits$WaterLevel), waterLevelLabels)
  # eden_epaNveg_planningUnits$WL_des_colors  <- plyr::revalue(as.factor(eden_epaNveg_planningUnits$WaterLevel), waterLevelColors)
  ###
  eden_epaNveg_planningUnits$area           <- sf::st_area(eden_epaNveg_planningUnits) * 0.000247105
  
  keep_these<-st_is(eden_epaNveg_planningUnits,c("MULTIPOLYGON","POLYGON"))
  out<-eden_epaNveg_planningUnits[keep_these,] #changed what filename is being written out here
  output_shapefile=paste0("outputs\\risk_map",EDEN_date,"0415_everfuel_cmdem.shp")
  
  ### export as shapefile
  if (!is.null(output_shapefile)) { # nocov start
    # sf::st_write(obj = eden_epaNveg_planningUnits, output_shapefile, delete_layer = TRUE, driver="ESRI Shapefile") 
    sf::st_write(obj = out, driver="ESRI Shapefile", dsn = output_shapefile, overwrite = TRUE)
    # rgdal::writeOGR(eden_epaNveg_planningUnits, output_shapefile, driver="ESRI Shapefile")
    # rgdal::writeOGR(eden_epaNveg_planningUnits, output_shapefile, driver="GPKG")
  }
  
  if (!is.null(csvExport)) { # nocov start
    ### Create a summary table of fire risk area for each planning unit
    ### and export as csv
    keyVars_df       <- sf::st_set_geometry(eden_epaNveg_planningUnits, NULL)                                                # Drop geometry for summing each column for total values
   # planFMUs         <- dplyr::summarize(.data = dplyr::group_by(.data = keyVars_df, PlanningUn, FMU_Name, WF_Use), .groups = 'drop', 
    planFMUs         <- dplyr::summarize(.data = dplyr::group_by(.data = keyVars_df, PlanningUn, FMU_Name, risk_names), .groups = 'drop', 
                                                  area_acres = sum(area))                 # Summarize data (mean) by planning units
    is.num           <- sapply(planFMUs, is.numeric)                                                                        
    planFMUs[is.num] <- lapply(planFMUs[is.num], round, 2)
    csvExport<-paste0("outputs\\risk_planunits_",EDEN_date,".csv")
    utils::write.csv(planFMUs, file = csvExport, row.names = FALSE)       
  }
  
  
}
  
#   
#   
#   ### export as image
#   if (!is.null(waterLevelExport)) {
#     dataToPlot    <- "WL_des"
#     # group.colors  <- as.character(eden_epaNveg_planningUnits$WaterLevel)
#     dataToPlot    <- "WaterLevel"
#     dataLabels    <- unique(eden_epaNveg_planningUnits$WL_des)[order(as.numeric(unique(eden_epaNveg_planningUnits$WaterLevel)))]
#     legendLabel   <- paste0("Water Levels\n", EDEN_date2)
#     group.colors  <- rev(waterLevelColors)
#     
#     # group.colors  <- c("7" = "firebrick",
#     #                    "6" = "orangered3",
#     #                    "5" = "orange",
#     #                    "4" = "yellow1",  # new category introduced 20190222
#     #                    "3" = "yellow3",
#     #                    "2" = "green4",
#     #                    "1" = RColorBrewer::brewer.pal(9, "Greens")[4],
#     #                    "0" = RColorBrewer::brewer.pal(9, "Blues")[4])
#     
#     # group.colors$WaterLevel <- factor(eden_epaNveg_planningUnits$WaterLevel, levels=unique(eden_epaNveg_planningUnits$WaterLevel[order(eden_epaNveg_planningUnits$WaterLevel)]), ordered=TRUE)
#     # group.colors$WaterLevel <- unique(eden_epaNveg_planningUnits$WL_des)[order(as.numeric(unique(eden_epaNveg_planningUnits$WaterLevel)))]
#     
#     ### TODO: remove these calls to as.character(get(x))
#     ggplot2::ggplot() + ggplot2::geom_sf(data = eden_epaNveg_planningUnits, ggplot2::aes(fill = as.character(get(dataToPlot))), 
#                                          col = NA, lwd = 0, alpha = 1) + 
#       ggplot2::geom_sf(data = BICY_EVER_PlanningUnits_shp, alpha = 0, col = "black", 
#                        lwd = 0.05, show.legend = FALSE) + 
#       ggplot2::geom_sf(data = BICY_EVER_PlanningUnits_shp[!BICY_EVER_PlanningUnits_shp$FMU_Name %in% "Pinelands",], alpha = 0, col = "black", 
#                        lwd = 0.25, show.legend = FALSE) + 
#       ggplot2::theme_bw(base_size = ggBaseSize) + ggplot2::labs(fill = legendLabel) + 
#       ggplot2::scale_fill_manual(values=group.colors, labels = dataLabels, drop = FALSE)  + 
#       ggplot2::scale_colour_manual(values=group.colors, labels = dataLabels, guide = FALSE) 
#     
#     # ggplot2::scale_fill_brewer(palette = legendPalette, direction=-1) +  ggplot2::scale_colour_brewer(palette= legendPalette, direction = -1, guide = "none")
#     for (i in 1:length(waterLevelExport)) {
#       ggplot2::ggsave(file = waterLevelExport[i], width = figureWidth, height = figureHeight, units = "in")
#     }
#   } 
#   
#   
#   if (!is.null(fireSpreadExport)) {
#     dataToPlot    <- "WF_Use"
#     legendLabel   <- paste0("Fire Spread Risk \n", EDEN_date2)
#     
#     
#     
#     group.colors  <- c(
#       `High`            = "brown4",
#       `Moderately High` = "darkorange1",
#       `Moderate`        = "yellow3",
#       `Moderately Low`  = "deepskyblue2",
#       `Low`             = "chartreuse4"
#     )
#     # group.colors  <- c(
#     #   "1"  = RColorBrewer::brewer.pal(9, "Reds")[4],
#     #   "2"  = RColorBrewer::brewer.pal(9, "Oranges")[4],
#     #   "3"  = RColorBrewer::brewer.pal(9, "YlOrBr")[2],
#     #   "4"  = RColorBrewer::brewer.pal(9, "Blues")[4],
#     #   "5"  = RColorBrewer::brewer.pal(9, "Greens")[4]
#     # )
#     # dataLabels    <- names(group.colors) <- riskNames
#     dataLabels    <- names(group.colors)
#     
#     if (burnHist) {
#       ### do some additional processing
#       eden_epaNveg_planningUnits <- sf::st_buffer(eden_epaNveg_planningUnits, dist = 0)
#       
#       # if(is.null(burnData[[1]])) {
#       #   
#       # }
#       burnData = list(fireHydro::fire182, fireHydro::fire192, fireHydro::fire_2020)
#       withCallingHandlers(
#         high17                <- sf::st_intersection(eden_epaNveg_planningUnits, burnData[[1]]), warning = fireHydro::intersectionWarningHandler)  
#       high17$WF_Use         <- factor(high17$WF_Use)
#       levels(high17$WF_Use) <- c(riskNames[2], riskNames[length(riskNames)])
#       
#       withCallingHandlers( # if an error occurs, may need to change other years to use a2 
#         high18                <- sf::st_intersection(eden_epaNveg_planningUnits, burnData[[2]]), warning = fireHydro::intersectionWarningHandler)  
#       high18$WF_Use         <- factor(high18$WF_Use)
#       levels(high18$WF_Use) <- c(riskNames[3], riskNames[length(riskNames)])
#       
#       withCallingHandlers(
#         high19                <- sf::st_intersection(eden_epaNveg_planningUnits, burnData[[3]]), warning = fireHydro::intersectionWarningHandler)  
#       high19$WF_Use         <- factor(high19$WF_Use)
#       levels(high19$WF_Use) <- c(riskNames[4], riskNames[length(riskNames)])
#       
#       eden_epaNveg_planningUnits$WF_Use         <- factor(eden_epaNveg_planningUnits$WF_Use)
#       levels(eden_epaNveg_planningUnits$WF_Use) <- c(riskNames[1], riskNames[length(riskNames)])
#       levels(eden_epaNveg_planningUnits$WF_Use) <- c(levels(eden_epaNveg_planningUnits$WF_Use), dataLabels[!dataLabels %in% levels(eden_epaNveg_planningUnits$WF_Use)]) 
#       eden_epaNveg_planningUnits$WF_Use         <- factor(eden_epaNveg_planningUnits$WF_Use, levels = riskNames)
#       
#       ### TODO: merge fire history maps back into main object
#       burn <- do.call(rbind, list(
#         sf::st_buffer(high17, dist = 1),
#         sf::st_buffer(high18, dist = 1),
#         sf::st_buffer(high19, dist = 1)
#       ))
#       # table(burn$WF_Use)
#       
#       eden_epaNveg_planningUnits <- rbind(eden_epaNveg_planningUnits, burn[, names(eden_epaNveg_planningUnits)])
#       ###
#       
#       
#       ggplot() + geom_sf(data = eden_epaNveg_planningUnits, aes(fill = get(dataToPlot)), col = NA, alpha = 1, lwd = 0) + theme_bw(base_size = 12)  +
#         # ggplot2::geom_sf(data = high17, alpha = 1,
#         #                  aes(fill = get(dataToPlot), col = get(dataToPlot)),
#         #                  lwd = 0.0, show.legend = FALSE)  +
#         # ggplot2::geom_sf(data = high18, alpha = 1,
#         #                  aes(fill = get(dataToPlot), col = get(dataToPlot)),
#         #                  lwd = 0.0, show.legend = FALSE)  +
#         # ggplot2::geom_sf(data = high19, alpha = 1,
#         #                  aes(fill = get(dataToPlot), col = get(dataToPlot)),
#         #                  lwd = 0.0, show.legend = FALSE) +
#         ggplot2::geom_sf(data = BICY_EVER_PlanningUnits_shp, alpha = 0, col = "black", 
#                          lwd = 0.05, show.legend = FALSE) + 
#         ggplot2::geom_sf(data = BICY_EVER_PlanningUnits_shp[!BICY_EVER_PlanningUnits_shp$FMU_Name %in% "Pinelands",], alpha = 0, col = "black", 
#                          lwd = 0.25, show.legend = FALSE) +
#         ggplot2::labs(fill = legendLabel) +
#         ggplot2::scale_fill_manual(values=group.colors, labels = dataLabels, drop = FALSE)  +
#         ggplot2::scale_colour_manual(values=group.colors, labels = dataLabels, guide = FALSE)
#       
#     }
#     
#     if (!burnHist) { # fire spread risk map without burn history
#       # legendPalette <- "Reds"
#       group.colors  <- c(`High` = "brown4", `Low` = "ivory3")
#       dataLabels    <- names(group.colors)
#       
#       ggplot2::ggplot() + ggplot2::geom_sf(data = eden_epaNveg_planningUnits, ggplot2::aes(fill = as.character(get(dataToPlot))), col = NA, lwd = 0, alpha = 1) + 
#         ggplot2::geom_sf(data = BICY_EVER_PlanningUnits_shp, alpha = 0, col = "black", 
#                          lwd = 0.05, show.legend = FALSE) + 
#         ggplot2::geom_sf(data = BICY_EVER_PlanningUnits_shp[!BICY_EVER_PlanningUnits_shp$FMU_Name %in% "Pinelands",], alpha = 0, col = "black", 
#                          lwd = 0.25, show.legend = FALSE) + 
#         ggplot2::theme_bw(base_size = ggBaseSize) + ggplot2::labs(fill = legendLabel) + 
#         ggplot2::scale_fill_manual(values=group.colors, labels = dataLabels, drop = FALSE)  + 
#         ggplot2::scale_colour_manual(values=group.colors, labels = dataLabels, guide = FALSE) 
#     }
#     
#     # ggplot2::scale_fill_brewer(palette = legendPalette, direction=-1) +  ggplot2::scale_colour_brewer(palette= legendPalette, direction = -1, guide = "none")
#     for (i in 1:length(fireSpreadExport)) {
#       ggplot2::ggsave(file = fireSpreadExport[i], width = figureWidth, height = figureHeight, units = "in")
#     }
#   }
#   
#   # nocov end
#   if (returnShp) {
#     invisible(eden_epaNveg_planningUnits)
#   }
# #}
