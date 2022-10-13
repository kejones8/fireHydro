library(sf)
library(rmapshaper)



#read in whole area veg layer
vegetation_shp<-read_sf("data\\diss_veg_ever_bicy.shp") #original veg, now reading in extended veg
vegetation_shp<-read_sf("data\\extended_veg.shp")

#create table that assigns risk values to fuel types
veg_fuel<-c("GR1","GR3","GR8","GS3","NB1","NB3","NB8","NB9","SH6","TL2","TL4")
veg_risk<-c(4,3,2,5,9,8,9,9,1,7,6)
vegTbl <-data.frame(veg_fuel=veg_fuel,veg_risk=veg_risk)

#just putting this in here to get CRS correct
load("data\\BICY_EVER_PlanningUnits.RData")
utm_crs<-st_crs(BICY_EVER_PlanningUnits)

#put it in the correct crs...need to make this such that it matches other spatial data in utm 17n
####LINE BELOW NEEDS TO BE CHANGED (havent read in planning units_shp)
veg_shp_trans       <- sf::st_transform(vegetation_shp, sf::st_crs(utm_crs))

#change colnames
vegetation_reclass <- veg_shp_trans[, c("L9_veg")]    

veggies<- unique(vegetation_shp$L9_veg)


colnames(vegetation_reclass)      <- c("Veg_Cat","geometry")


#could load these as already created files
veg_reclass<-merge(vegetation_reclass,vegTbl,by.x="Veg_Cat",by.y="veg_fuel")

veg_simp_kpshp_pnt3 <- rmapshaper::ms_simplify(veg_reclass,keep=0.3,keep_shapes = TRUE)
#veggies<- unique(vegetation_shp$Veg_Cat)


#veg_buf <- st_buffer(veg_simp_kpshp_pnt3,0)#moved these into the for loop because it was bonkers to buf/val the whole layer....
#veg_val<-st_make_valid(veg_buf)#moved these into the for loop because it was bonkers to buf/val the whole layer....


for (i in 1:length(veggies)){
  cat<-veggies[i]
  veg<-veg_simp_kpshp_pnt3[veg_simp_kpshp_pnt3$Veg_Cat== cat,]
  veg_buf <- st_buffer(veg,0)#moved these into the for loop because it was bonkers to buf/val the whole layer....
  veg_val<-st_make_valid(veg_buf)
  #veg_simp_kpshp_pnt3 <- rmapshaper::ms_simplify(veg,keep=0.3,keep_shapes = TRUE)
  #veg_buf <- st_buffer(veg_simp_kpshp_pnt3,0)
  #veg_val<-st_make_valid(veg_buf)
  write_sf(veg_val,paste0("data\\ext_veg_simp_whole_",cat,".shp"))
  
}

######Think the stuff below here is just a test??

eden_epa_reclass<-read_sf("tests\\eden_epa_reclass_20170303.shp")
# #simplify it for buffer

# #veg_simp_kpshp_pnt1 <- rmapshaper::ms_simplify(veg_reclass,keep=0.1,keep_shapes = TRUE)
# #veg_simp_keepshapes <- rmapshaper::ms_simplify(veg_reclass,keep_shapes = TRUE)
# #veg_simp <- rmapshaper::ms_simplify(veg_reclass)
# write_sf(veg_simp_kpshp_pnt35,"tests\\vegmap_simp_v6kpshp_pnt35.shp")
# write_sf(veg_simp,"tests\\vegmap_simp_v1_def.shp")
# write_sf(veg_simp_keepshapes,"tests\\vegmap_simp_v1_kpshp.shp")
eden_buf <- st_buffer(eden_epa_reclass,0)
eden_val<-st_make_valid(eden_buf)



library(foreach)
library(doParallel)


registerDoParallel(makeCluster(12))
ptm <- proc.time()
print(Sys.time())

didthiswork_nosimp_edenlatenightwl<-foreach(i=veggies, .combine = rbind, .packages='sf')  %dopar%  {
  #myvars = c("LONG_X","LAT_Y")
  veg_type <- read_sf(paste0("data\\veg_simp_",i,".shp"))
  # veg_buf <- st_buffer(veg_type,0)
  # veg_val<-st_make_valid(veg_buf)
  inter<-sf::st_intersection(veg_type,eden_val)
  st_buffer(inter,0)
  
  #spdf <- SpatialPointsDataFrame(coords = producers_lat_long, data = split_df,
                                 #proj4string = CRS("+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0"))
  
  #clip1 = point.in.poly(spdf, all_polygons)
  #getValues(clip1)
}
print(Sys.time())
proc.time() - ptm
endCluster()

#doesthiswork<-st_make_valid(didthiswork_nosimp_edenlatenightwl)
#bufferwork<-st_buffer(didthiswork_nosimp_edenlatenightwl,0)


write_sf(didthiswork_nosimp_edenlatenightwl,"par_output_20180410_0419pm.shp")
#write_sf(bufferwork,"par_output_20170911.shp")

eden_epaNveg<-read_sf("par_output_20180410_0419pm.shp")

# copying other stuff from getFireHydro
eden_epaNveg<-didthiswork_nosimp_edenlatenightwl

names(eden_epaNveg)[names(eden_epaNveg) == 'WatrLvl'] <- 'WaterLevel'
names(eden_epaNveg)[names(eden_epaNveg) == 'veg_rsk'] <- 'veg_risk'

eden_epaNveg$rval_wat_veg<-eden_epaNveg$veg_risk*eden_epaNveg$WaterLevel


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

eden_epaNveg_planningUnits              <- sf::st_intersection(eden_epaNveg, trans_planningUnits_shp[, c("Unit_Code", "FMU_Name")], warning = fireHydro::intersectionWarningHandler)

eden_epaNveg_planningUnits$WL_des         <- as.factor(eden_epaNveg_planningUnits$WaterLevel)
levels(eden_epaNveg_planningUnits$WL_des) <- waterLevelLabels[names(waterLevelLabels) %in% unique(eden_epaNveg_planningUnits$WaterLevel)]

eden_epaNveg_planningUnits$WL_des_colors         <- as.factor(eden_epaNveg_planningUnits$WaterLevel)
levels(eden_epaNveg_planningUnits$WL_des_colors) <- waterLevelLabels[names(waterLevelLabels) %in% unique(eden_epaNveg_planningUnits$WaterLevel)]

eden_epaNveg_planningUnits$area           <- sf::st_area(eden_epaNveg_planningUnits) * 0.000247105

keep_these<-st_is(eden_epaNveg_planningUnits,c("MULTIPOLYGON","POLYGON"))
out<-eden_epaNveg_planningUnits[keep_these,] #changed what filename is being written out here
output_shapefile=paste0("outputs\\risk_map",EDEN_date,"_newdem_erc.shp")

sf::st_write(obj = out, driver="ESRI Shapefile", dsn = output_shapefile, overwrite = TRUE)

#because the buffering and intersecting takes so long on one large file, doing the veg work here, first
#such that the buffered veg types can simply be loaded, intersected, and unioned with
#the edenepa water data
# 
# 
# veg_class_list<-unique(veg_reclass$Veg_Cat)
# 
# for (i in 1:length(veg_class_list)){
#   
#   veg<-veg_class_list[i]
#   veg_simp<-sf::st_simplify(gr1_veg,dTolerance=2,preserveTopology=TRUE)
#   sing_veg_class<-st_buffer(veg_simp,0)
#   sf::st_write(sing_veg_class,paste0("tests\\veg_classes\\fuel_",i,".shp"))
#   
# }





