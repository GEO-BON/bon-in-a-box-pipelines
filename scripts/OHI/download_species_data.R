library(gh)
library(tidyverse)

files <- gh("GET /repos/{owner}/{repo}/contents/{path}",
            owner = "OHI-Science",
            repo  = "ohi-global",
            path  = "eez/layers")
input <- biab_inputs()

file_names <- vapply(files, function(x) x$name, character(1))
download_urls <- vapply(files, function(x) x$download_url, character(1))

# Match EEZ to code
print(input$country_region$country$ISO3)
eez_codes <- read_csv("https://raw.githubusercontent.com/OHI-Science/ohi-global/refs/heads/draft/eez/spatial/regions_list.csv")
eez_code_filt <- eez_codes |> filter(eez_iso3 == input$country_region$country$ISO3)
print(eez_code_filt)

# Download species file paths (start with spp)
file_names_spp <- file_names[grepl("^spp", file_names, ignore.case = TRUE)]
download_urls_spp <- download_urls[file_names %in% file_names_spp]
print(download_urls_spp)

print(input$year)
spp_file_paths <- c()
for (i in seq_along(file_names_spp)) {
 df <- read.csv(download_urls[i], stringsAsFactors = FALSE) |> filter(rgn_id == eez_code_filt$rgn_id) |> filter(year == max(year))
 dest <- file.path(outputFolder, file_names_spp[i])
 write.csv(df, dest)
 spp_file_paths <- rbind(spp_file_paths, dest)
}

spp_trend_path <- spp_file_paths[grepl("trend", spp_file_paths, ignore.case = TRUE)]
print(spp_trend_path)
spp_status_path <- spp_file_paths[grepl("status", spp_file_paths, ignore.case = TRUE)]
print(spp_status_path)

biab_output("spp_trend", spp_trend_path)
biab_output("spp_status", spp_status_path)