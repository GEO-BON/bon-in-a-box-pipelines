library(tidyverse)
if (!require("ohicore")) {
    devtools::install_github("OHI-Science/ohicore")
    library(ohicore)
  }


input <- biab_inputs()
# Call the functions script
path_script <- Sys.getenv("SCRIPT_LOCATION")
source(file.path(path_script, "ohi/functions.R"), echo = TRUE)

# Load habitat layers
csv_files_hab <- input$habitat_layers
data_list <- lapply(csv_files_hab, read.csv)
names(data_list) <- tools::file_path_sans_ext(basename(csv_files_hab))


# Call habitat function
habitat_st <- HAB(data_list)
print(habitat_st)

path <- file.path(outputFolder, "habitat_st.csv")
write.csv(habitat_st, path)
biab_output("habitat_st_scores", path)
