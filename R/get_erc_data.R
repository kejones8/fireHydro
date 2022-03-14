#after catching up with Jill, she provided the links to the ERC data to pull for Big Cypress & Everglades
#all of the data can be accessed through an xml 


#this function gets called in kj_getFireHydro.R to add ERC to risk eval
#...but don't have this connected yet


get_mean_erc<-function(date){# "20181018" date format provided in getFireHydro.R
  
library(xml2) #handling xmls
library(downloader) #this was streamlined for downloading (no calling of wget/curl, just url)

  
#get date into correct format for pulling from ERC urls
yr<-substr(date, 3, 4)
mnth_num<-as.integer(sub("^0+", "",substr(date, 5, 6))) #get 2 dig mnth, delete leading zero if necessary, make integer
mnth<-month.abb[mnth_num] #converts numeric mnth to text abbrev. for url
day<-substr(date, 7, 8)

#these are the station ids for which ERC is evaluated in both big cypress and everglades
stat_to_pull<-c(86401,
                86402,
                86403,
                86404,
                86301,#first 5 big cypress, last 2 everglades
                86404,
                86704) #Oasis, Miles City, Ochopee, Raccoon Point, Honeymoon, Cache, Chekika


erc_vals<-c() #create an empty vector to add the pulled ERC values

for (i in stat_to_pull){ #go through the list of stations

#need to understand if repeatedly using "user=lbradshaw" is a bad thing?
url<-paste0('https://famprod.nwcg.gov/wims/xsql/nfdrs.xsql?stn=',i,'&sig=&user=lbradshaw&type=&start=',day,"-",mnth,"-",yr,"&end=",day,"-",mnth,"-",yr,'&time=&priority=&fmodel=&sort=asc&ndays=')
print(url)
#download the xml file to a folder in repo and create temporary file, gets removed later in loop

dest_file <-paste0("./temp/erc_",as.character(date),"stat_",i,".xml")

download(url=url, 
         destfile = dest_file,
         extra = getOption("--no-check-certificate"))#added for systems w/ dif. security permissions?

xml_lst<-as_list(read_xml(dest_file)) #convert xml file to a list for easier access
file.remove(dest_file) #no remove file that I have info in memory

erc<-as.double(unlist(xml_lst$nfdrs$row$ec)) #get the erc value
  
erc_vals<-c(erc_vals,erc)#append it list of erc values for that day 

}

#### EVENTUALLY might want this to be 2 different average values for BICY & EVER
mean_erc<-mean(erc_vals) #get average value

return(list(round(mean_erc),erc_vals))#return the average ERC

}


date="20220310" #format of date to pass in 
get_mean_erc(date) #run function
