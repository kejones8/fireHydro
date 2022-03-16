library(fireHydro)

#read in area we want to crop too
#this is for development purposes, lessen processing time
test_area<-read_sf("C:\\Users\\thebrain\\Dropbox\\LCLab\\Everglades\\firehydro_working\\old\\fireHydro_repo_03012022\\fireHydro-master\\fireHydro-master\\data//new_0322data//test_area.shp")

#trying get EDEN to make sure I can pull it down
a<-getEDEN() #gets the most recent data
eden_poly<-a$data #a is a list with date & then sf data, we want the data
###!!!! although, the date is what we'll pass to the ERC function
eden_utm<-st_set_crs(eden_poly,st_crs(test_area))#eden isn't ingested with good CRS, set it

#now crop eden to smaller area
eden_test_area<-st_crop(eden_utm,st_bbox(test_area))

#export as EDEN test area and figure out how to call in firehydro
write_sf(eden_test_area,"C:\\Users\\thebrain\\Dropbox\\LCLab\\Everglades\\firehydro_working\\old\\fireHydro_repo_03012022\\fireHydro-master\\fireHydro-master\\data//new_0322data//eden_test_area.shp")


old_veg_testarea<-read_sf("C:\\Users\\thebrain\\Dropbox\\LCLab\\Everglades\\firehydro_working\\old\\fireHydro_repo_03012022\\fireHydro-master\\fireHydro-master\\data//new_0322data//old_veg_test_area.shp")

new_veg_testarea<-read_sf("C:\\Users\\thebrain\\Dropbox\\LCLab\\Everglades\\firehydro_working\\old\\fireHydro_repo_03012022\\fireHydro-master\\fireHydro-master\\data//new_0322data//test_area_veg.shp")
