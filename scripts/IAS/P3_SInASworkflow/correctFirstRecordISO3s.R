
correctISO3s_wb <- openxlsx::loadWorkbook(file.path(workingDirectory,subDirectory,"Config","AllLocations.xlsx"))

##update incorrect ISO3 codes in Sheet 2 - location
correctISO3s_Data_Info <- openxlsx::read.xlsx(correctISO3s_wb, sheet = "location",
                                 colNames = TRUE)


correctISO3s_Data_Info_Altered <- correctISO3s_Data_Info %>% 
  dplyr::mutate(ISO3 = ifelse(ISO3 == "TTO" & location == "Timor-Leste", "TLS", ISO3)) %>%
  dplyr::mutate(ISO3 = ifelse(ISO3 == "ANT" & location == "Curaçao", "CUW", ISO3)) %>%
  dplyr::mutate(ISO3 = ifelse(ISO3 == "ANT" & location == "Sint Maarten", "SXM", ISO3)) %>%
  dplyr::mutate(ISO3 = ifelse(ISO3 == "SDN" & location == "South Sudan", "SSD", ISO3)) %>%
  dplyr::mutate(gadm0_name = ifelse(ISO3 == "SSD" & location == "South Sudan", "South Sudan", gadm0_name)) %>%
  dplyr::mutate(gadm0_name = ifelse(ISO3 == "SRB" & location == "Serbia", "Serbia", gadm0_name)) %>%
  dplyr::mutate(location_var = ifelse(ISO3 == "CIV", paste0(location_var,"; Côte d Ivoire"), location_var)) %>%
  dplyr::mutate(location_var = ifelse(ISO3 == "PRK", paste0(location_var,"; Korea, Democratic People s Republic of"), location_var))

openxlsx::writeData(correctISO3s_wb, sheet = "location", x = correctISO3s_Data_Info_Altered,
                    startCol = "A",
                    startRow = 1,
                    colNames = TRUE)
openxlsx::saveWorkbook(correctISO3s_wb, file.path(workingDirectory, subDirectory, "Config/AllLocations.xlsx"), overwrite = TRUE)


##update incorrect ISO3 codes in Sheet 3 - stateProvince
correctISO3s_Data_Info2 <- openxlsx::read.xlsx(correctISO3s_wb, sheet = "stateProvince",
                                 colNames = TRUE)

correctISO3s_Data_Info_Altered2 <- correctISO3s_Data_Info2 %>% 
  dplyr::mutate(ISO3 = ifelse(ISO3 == "TTO" & location == "Timor-Leste", "TLS", ISO3)) %>%
  dplyr::mutate(ISO3 = ifelse(ISO3 == "SDN" & location == "South Sudan", "SSD", ISO3)) %>%
  dplyr::mutate(gadm0_name = ifelse(ISO3 == "SSD" & location == "South Sudan", "South Sudan", gadm0_name)) %>%
  dplyr::mutate(gadm0_name = ifelse(ISO3 == "SRB" & location == "Serbia", "Serbia", gadm0_name)) %>%
  dplyr::mutate(location_var = ifelse(ISO3 == "CIV", paste0(location_var,"; Côte d Ivoire"), location_var)) %>%
  dplyr::mutate(location_var = ifelse(ISO3 == "PRK", paste0(location_var,"; Korea, Democratic People s Republic of"), location_var))

openxlsx::writeData(correctISO3s_wb, sheet = "stateProvince", x = correctISO3s_Data_Info_Altered2,
                    startCol = "A",
                    startRow = 1,
                    colNames = TRUE)
openxlsx::saveWorkbook(correctISO3s_wb, file.path(workingDirectory, subDirectory, "Config/AllLocations.xlsx"), overwrite = TRUE)

rm(list=ls(pattern = "correctISO3s_"))
