# Load libraries
if (!require("red")) install.packages("red")

packagesList <- list("magrittr", "ggplot2", "rredlist", "red") # Explicitly list the required packages throughout the entire routine. Explicitly listing the required packages throughout the routine ensures that only the necessary packages are listed. Unlike 'packagesNeed', this list includes packages with functions that cannot be directly called using the '::' syntax. By using '::', specific functions or objects from a package can be accessed directly without loading the entire package. Loading an entire package involves loading all the functions and objects
lapply(packagesList, library, character.only = TRUE) # Load libraries - packages

input <- biab_inputs()

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

# Redlist data ####
print("red")
redlist_data <- red::rli(matrix_output, boot = F) %>%
  t() %>%
  as.data.frame() %>%
  tibble::rownames_to_column("Year") %>%
  setNames(c("Year", "RLI")) %>%
  dplyr::filter(!Year %in% "Change/year")
print("redlist_data")


# Redlist figura ####
redlist_trend_plot <- ggplot(redlist_data, aes(x = as.numeric(Year), y = RLI)) +
  scale_x_continuous(breaks = seq(1960, as.numeric(format(Sys.Date(), "%Y")), by = 2)) +
  labs(x = "year", y = "Red List Index") +
  geom_line(group = 1, col = "red") +
  geom_point() +
  coord_cartesian(xlim = c(1960, as.numeric(format(Sys.Date(), "%Y"))), ylim = c(0, 1)) +
  theme_classic() +
  theme(panel.grid.major = element_line(color = "gray")) +
  theme(text = element_text(size = 4)) +
  ggtitle("RLI for selected taxonomy group and country") +
  theme(plot.title = element_text(hjust = 0.5)) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 2))


## Write results ####
redlist_data_path <- file.path(outputFolder, paste0("redlist_data", ".csv")) # Define the file path
write.csv(redlist_data, redlist_data_path, row.names = F)

redlist_matrix_path <- file.path(outputFolder, paste0("redlist_matrix", ".csv")) # Define the file path
write.csv(matrix_output, redlist_matrix_path, row.names = T)

redlist_trend_plot_path <- file.path(outputFolder, paste0("redlist_trend_plot", ".jpg")) # Define the file path
ggsave(redlist_trend_plot_path, redlist_trend_plot, height = 2, width = 4)

biab_output("redlist_trend_plot", redlist_trend_plot_path)
biab_output("redlist_data", redlist_data_path)
biab_output("redlist_matrix", redlist_matrix_path)
