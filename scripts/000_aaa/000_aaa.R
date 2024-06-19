

## Set output folder ####
# Option 1: Setting for production pipeline purposes. This is designed for use in a production environment or workflow.


print(Sys.getenv("IUCN_TOKEN"))

token <- Sys.getenv("IUCN_TOKEN")
df_IUCN_sheet <- rredlist::rl_search("Icterus chrysater", key = token)$result
print(df_IUCN_sheet)
