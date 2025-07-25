#-------------------------------------------------------------------------------
# This script takes all the tables with the Species Habitat Scores and the areas for the
# total range map and the area of habitat calculated to produce the Species Habitat Index
# and the Steward's Species Habitat Index
#-------------------------------------------------------------------------------
# Script location can be used to access other scripts
print(Sys.getenv("SCRIPT_LOCATION"))
options(timeout = max(60000000, getOption("timeout")))

packages <- list("dplyr", "purrr", "readr", "ggplot2", "rjson")

lapply(packages, library, character.only = TRUE)

path_script <- Sys.getenv("SCRIPT_LOCATION")

input <- biab_inputs()
print("Inputs: ")
print(input)

#-------------------------------------------------------------------------------
# Load all tables
#-------------------------------------------------------------------------------
# Define species
output <- tryCatch(
  {
    path_shs <- input$df_shs_tidy
    path_aoh_areas <- input$df_aoh_areas

    print(path_aoh_areas)

    # Load SHS tables
    l_df_SHS_sp <- map(path_shs, ~ read_tsv(.x))
    df_SHS_sp <- bind_rows(l_df_SHS_sp)
    print(df_SHS_sp)

    # Load area tables
    df_aoh_areas <- read_tsv(path_aoh_areas) |> mutate(W_stewardship = area_aoh / area_range_map)
    print(df_aoh_areas)

    # Join tables
    df_SHS_aoh_areas_sp <- df_SHS_sp |>
      filter(Score == "SHS") |>
      left_join(df_aoh_areas, by = "sci_name", relationship = "many-to-one")

    #-------------------------------------------------------------------------------
    # Calculate SHI
    #-------------------------------------------------------------------------------

    df_SHI <- df_SHS_aoh_areas_sp |>
      group_by(Year) |>
      summarise(SHI = round(mean(Values), 2), Steward_SHI = round(weighted.mean(Values, W_stewardship), 2))
    path_SHI <- file.path(outputFolder, "SHI_table.tsv")
    print(df_SHI)
    write_tsv(df_SHI, file = path_SHI)

    # Plot
    img_SHI_timeseries <- ggplot(df_SHI, aes(x = Year, y = SHI)) +
      geom_line(size = 1) +
      theme_bw() +
      ylab("Species Habitat Index (%)") +
      scale_y_continuous(breaks = seq(0, 110, 20)) +
      coord_cartesian(ylim = c(0, 110))

    path_img_SHI_timeseries <- file.path(outputFolder, "SHI_timeseries.png")
    ggsave(path_img_SHI_timeseries, img_SHI_timeseries, dpi = 300, width = 6, height = 4)

    img_W_SHI_timeseries <- ggplot(df_SHI, aes(x = Year, y = Steward_SHI)) +
      geom_line(size = 1) +
      theme_bw() +
      ylab("Steward's Species Habitat Index (%)") +
      scale_y_continuous(breaks = seq(0, 110, 20)) +
      coord_cartesian(ylim = c(0, 110))

    path_img_W_SHI_timeseries <- file.path(outputFolder, "Steward_SHI_timeseries.png")
    ggsave(path_img_W_SHI_timeseries, img_W_SHI_timeseries, dpi = 300, width = 6, height = 4)

    #-------------------------------------------------------------------------------
    # Outputing result
    biab_output("df_shi", path_SHI)
    biab_output("img_shi_timeseries", path_img_SHI_timeseries)
    biab_output("img_w_shi_timeseries", path_img_W_SHI_timeseries)
  },
  error = function(e) {
    list(error = conditionMessage(e))
  }
)
