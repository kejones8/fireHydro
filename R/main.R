library(fireHydro)
library(sf)

#read in area we want to crop too
#this is for development purposes, lessen processing time
test_area<-read_sf("C:\\Users\\thebrain\\Dropbox\\LCLab\\Everglades\\firehydro_working\\old\\fireHydro_repo_03012022\\fireHydro-master\\fireHydro-master\\data//new_0322data//test_area.shp")


source("R\\getEDEN.R")


eden_poly<-read_sf("tests\\eden_wtrdpt_20220310_ftgrdDEM_narm.shp")

#trying get EDEN to make sure I can pull it down
#DID NOT RUN THE NEXT 2 LINES BELOW SUCCESSFULLY
a<-getEDEN(EDEN_date = Sys.Date()) #gets the most recent data
eden_poly<-a$data #a is a list with date & then sf data, we want the data

#eden_poly<-read_sf("tests\\eden_wtrdpt_20220310_DEMconvmet.shp")

eden_poly<-EDEN_list$data
write_sf(eden_poly,"tests\\eden_wtrdpt_20170303_fh250m_cm.shp",overwrite=TRUE)
write_sf(eden_poly,"tests\\eden_wtrdpt_20170330_fh250m_cm.shp",overwrite=TRUE)
eden_poly<-read_sf("tests\\eden_wtrdpt_20170330_fh250m_cm.shp")
eden_poly<-read_sf("tests\\eden_wtrdpt_20170609_fh250m_cm.shp")
###i went in and manually ran the getEDEN() function with the new DEM and EDEN_date hard coded in (for the test area)
#going to spit out an eden a object, that I will then read into getFireHydro.R

date<-EDEN_list$date

write_sf(eden_poly,"tests\\eden_wtrdpt_20220310_edengrdorig.shp",overwrite=TRUE)

source("R\\get_erc_data.R")

erc_return<-get_mean_erc(date)

avg_erc<-unlist(erc_return[1])

source("R\\getFireHydro.R")



#also params to load here then pass in
#bicy planning units
#what else? 

vegetation_shp<-read_sf("data\\diss_veg_ever_bicy.shp")
load("data\\BICY_EVER_PlanningUnits.RData")
BICY_EVER_PlanningUnits_shp<-BICY_EVER_PlanningUnits

getFireHydro_kj(EDEN_date=date,eden_data=eden_poly,avg_erc=avg_erc)



###!!!! although, the date is what we'll pass to the ERC function
eden_utm<-st_set_crs(eden_poly,st_crs(test_area))#eden isn't ingested with good CRS, set it

#now crop eden to smaller area
eden_test_area<-st_crop(eden_utm,st_bbox(test_area))

#export as EDEN test area and figure out how to call in firehydro
write_sf(eden_test_area,"C:\\Users\\thebrain\\Dropbox\\LCLab\\Everglades\\firehydro_working\\old\\fireHydro_repo_03012022\\fireHydro-master\\fireHydro-master\\data//new_0322data//eden_test_area.shp")


old_veg_testarea<-read_sf("C:\\Users\\thebrain\\Dropbox\\LCLab\\Everglades\\firehydro_working\\old\\fireHydro_repo_03012022\\fireHydro-master\\fireHydro-master\\data//new_0322data//old_veg_test_area.shp")

new_veg_testarea<-read_sf("C:\\Users\\thebrain\\Dropbox\\LCLab\\Everglades\\firehydro_working\\old\\fireHydro_repo_03012022\\fireHydro-master\\fireHydro-master\\data//new_0322data//test_area_veg.shp")



###comparing risk maps 

