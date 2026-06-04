# Load libraries
if (!require("red")) install.packages("red")

packagesList <- list("magrittr", "ggplot2", "rredlist", "red") # Explicitly list the required packages throughout the entire routine. Explicitly listing the required packages throughout the routine ensures that only the necessary packages are listed. Unlike 'packagesNeed', this list includes packages with functions that cannot be directly called using the '::' syntax. By using '::', specific functions or objects from a package can be accessed directly without loading the entire package. Loading an entire package involves loading all the functions and objects
lapply(packagesList, library, character.only = TRUE) # Load libraries - packages

input <- biab_inputs()

taxonomic_group <- input$taxonomic_group
uses <- input$species_use
threats <- input$threat

#### Species list by country ####
# Load IUCN token----
history_assessment_data <- data.table::fread(input$history_assessment_data) %>% as.data.frame()
form_matrix <- as.formula(paste0(input$sp_col, "~", input$time_col))

historyAssesment_matrix <- reshape2::dcast(history_assessment_data, form_matrix,
  value.var = "code",
  fun.aggregate = function(x) {
    unique(x)[1]
  }
) %>%
  tibble::column_to_rownames(input$sp_col) %>%
  as.data.frame.matrix()

# Ajustar matriz de codigos de amenaza ####

########## Codigo redlist
adjust_categories <- data.frame(
  Cat_IUCN = c("CR", "DD", "EN", "EN", "DD", "DD", "LC", "LC", "LC", "NT", "DD", "NT", "RE", "VU", "VU"),
  code = c("CR", "DD", "E", "EN", "I", "K", "LC", "LR/cd", "LR/lc", "LR/nt", "NA", "NT", "R", "V", "VU")
)

redlist_matrix <- historyAssesment_matrix %>% as.matrix()

for (i in seq(nrow(adjust_categories))) {
  redlist_matrix[which(redlist_matrix == adjust_categories[i, ]$code, arr.ind = TRUE)] <- adjust_categories[i, ]$Cat_IUCN
}

for (j in unique(adjust_categories$Cat_IUCN)) {
  key <- c(tolower(j), toupper(j), j) %>% paste0(collapse = "|")
  redlist_matrix[which(grepl(key, redlist_matrix), arr.ind = T)] <- j
}

redlist_matrix[which((!redlist_matrix %in% adjust_categories$Cat_IUCN) & !is.na(redlist_matrix), arr.ind = TRUE)] <- NA

RedList_matrix_2 <- as.data.frame.matrix(redlist_matrix)
# Remove species that do not have an assessment before the base year, in this case set to the year 2000

replace_na_with_previous <- function(df, target_col) {
  for (col in (target_col - 1):2) {
    df[[target_col]] <- ifelse(is.na(df[[target_col]]), df[[col]], df[[target_col]])
  }
  return(df)
}

df <- RedList_matrix_2 %>% as.data.frame.matrix()
print("df")
print(colnames(df))
print(df)
if (ncol(df) > 1) {
  for (k in 2:ncol(RedList_matrix_2)) {
    df <- replace_na_with_previous(df, k)
  }
}
matrix_output <- RedList_matrix_2
if (ncol(matrix_output) > 1) {
  for (k in 2:ncol(matrix_output)) {
    matrix_output <- replace_na_with_previous(matrix_output, k)
  }
}

redlist_matrix_path <- file.path(outputFolder, paste0("redlist_matrix", ".csv")) # Define the file path
write.csv(matrix_output, redlist_matrix_path, row.names = T)
biab_output("redlist_matrix", redlist_matrix_path)

# Redlist data ####
print("red")
redlist_data <- red::rli(matrix_output, boot = F) %>%
  t() %>%
  as.data.frame() %>%
  tibble::rownames_to_column("Year") %>%
  setNames(c("Year", "RLI")) %>%
  dplyr::filter(!Year %in% "Change/year")
print("redlist_data")

#Add country name in plot title
title <- paste0("RLI for species in ", input$country$englishName)

#Write subtitle in plot based on inputs
subtitle_parts <- c()

if ("All" %in% taxonomic_group){
  subtitle_parts <- c(subtitle_parts, "Taxon groups: All")
} else {
  subtitle_parts <- c(subtitle_parts, paste0("Taxon groups: ", paste(taxonomic_group, collapse = ", ")))
}

if (!"Do not filter by species use or trade" %in% uses) {
  if ("All" %in% uses) {
    subtitle_parts <- c(subtitle_parts, "Uses and trades: All")
  } else {
    subtitle_parts <- c(subtitle_parts, paste0("Uses and trades: ", paste(uses, collapse = ", ")))
  }
}

if (!"Do not filter by threat category" %in% threats) {
  if ("All" %in% threats) {
    subtitle_parts <- c(subtitle_parts, "Threats: All")
  } else {
    subtitle_parts <- c(subtitle_parts, paste0("Threats: ", paste(threats, collapse = ", ")))
  }
}

subtitle_text <- if (length(subtitle_parts) > 0) {
  paste(subtitle_parts, collapse = "\n")
} else {
  NULL  # no subtitle if empty
}

filtered_data <- redlist_data[!is.na(redlist_data$RLI), ]

# Redlist figures ####
redlist_trend_plot <- ggplot(filtered_data, aes(x = as.numeric(Year), y = RLI)) +
  scale_x_continuous(breaks = seq(min(as.numeric(filtered_data$Year)), as.numeric(format(Sys.Date(), "%Y")), by = 5)) +
  labs(x = "Year", y = "Red List Index") +
  geom_line(group = 1, col = "red") +
  geom_point(size=0.5) +
  coord_cartesian(xlim = c(min(as.numeric(filtered_data$Year)), as.numeric(format(Sys.Date(), "%Y"))), ylim = c(0, 1)) +
  theme_bw() +
  #theme(panel.grid.major = element_line(color = "gray")) +
  theme(text = element_text(size = 4)) +
  ggtitle(title, subtitle = subtitle_text) +
  theme(plot.title = element_text(hjust = 0.5)) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 2))

## Write results ####
redlist_data_path <- file.path(outputFolder, paste0("redlist_data", ".csv")) # Define the file path
write.csv(redlist_data, redlist_data_path, row.names = F)

redlist_trend_plot_path <- file.path(outputFolder, paste0("redlist_trend_plot", ".jpg")) # Define the file path
ggsave(redlist_trend_plot_path, redlist_trend_plot, height = 2, width = 4)

biab_output("redlist_trend_plot", redlist_trend_plot_path)
biab_output("redlist_data", redlist_data_path)
