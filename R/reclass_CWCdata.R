####### 09/18/2022

#reclassifying veg CWC veg layer (outside of park boundaries) based on google file cross walk to convert CWC veg to current
#fuel types in firehydro. Will need someone to evaluate - hope to have conversation with Jill before running this veg & producing 'final' outputs
#specifically, need guidance on CWC "marshes" & "prairies & bogs"

#only want to do this for areas that we don't already have data, so need to clip away the existing fuels data first

#first, in qgis - 
#clipped CWC veg data to EDEN extent
#then dissolved veg data by NAME_STATE class
#then clipped away existing fuels extent (dissolved existing fuels diss_veg_ever_bicy.shp to get extent using )

library(sf)

`%notin%` <- Negate(`%in%`)

#read in clipeed & dissolved CWC data from my computer 
cwc<-read_sf("data\\CWC_outsideparkbound_north.shp")

#might want to clip it to be only the northern conservtion areas not parts near miami...

#assigned 
#keep it simple, then change after Jill's review
#write Jill an email to meet


#make reclass table 
current_fuels<-c("GR1","GR8","GR8","NB1","NB1","NB1","NB1","NB1",'NB1','NB1',"NB3","NB3","NB3","NB8","NB8","NB9","NB9","SH6","SH6","TL2","TL2","TL2","TL2","TL2","TL4","TL4","TL4","TL4","TL4","TL4")
current_CWC<-c("Prairies and Bogs","Freshwater Non-Forested Wetlands","Marshes","Communication", 
               "Exotic Plants", "High Intensity Urban", "Low Intensity Urban","Rural",
               "Transportation","Utilities","Other Agriculture","Vineyard and Nurseries","Cropland/Pasture","Cultural - Lacustrine", 
               "Cultural - Riverine","Cultural - Terrestrial","Extractive","Freshwater Forested Wetlands","Shrub and Brushland","Rockland Hammock",
               "Baygall", "Hydric Hammock","Mesic Hammock","Other Hardwood Wetlands","Cypress", 
               "Cypress/Tupelo (Cypress/Tupelo mixed)", "Dome Swamp", "Isolated Freshwater Marsh", "Isolated Freshwater Swamp", "Strand Swamp")



whatimmissing<-unique(cwc$NAME_STATE[cwc$NAME_STATE %notin% current_CWC]) #so far, seems like i on


#then change attribute values 
df<-as.data.frame(cbind(current_fuels,current_CWC))

merged<-merge(cwc,df,by.x="NAME_STATE",by.y="current_CWC")


#now, this needs to get merged with the existing vegetation data
currfuels<-read_sf("data\\diss_veg_ever_bicy.shp")

#figure out how to make it (firehydro running) ok if there are some holes in the veg data
#make attributes/structure projection the same, then rbind

merged_utm<-st_transform(merged,st_crs(currfuels))

mer_goodcols<-merged_utm[,c("current_fuels","geometry")]
curfuel_goodcols<-currfuels[,c("L9_veg","geometry")]

colnames(mer_goodcols)<-c("L9_veg","geometry")

extended_veg<-rbind(mer_goodcols,curfuel_goodcols)

#will need to run the make veg simplify script again to recreate new veg shapefiles/.Rdata layers for each fuel type

write_sf(extended_veg,"data\\extended_veg.shp")
