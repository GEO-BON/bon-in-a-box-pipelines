
# Reading inputs
input <- biab_inputs()
seconds <- input$seconds
fileIn <- input$some_csv_file

# Validations
if (!file.exists(fileIn)) {
  biab_error_stop(sprintf("File '%s' does not exist.", fileIn))
}

# Partial output
biab_output("target", seconds)


# Error simulation
if (seconds == 13) {
  biab_error_stop("seconds == 13, you're not lucky! This causes failure.")
}

# Processing simulation
cat("Looping with some delay to simulate processing...\n")
counter <- 0
for (x in 0:seconds) {
  cat(x, "\n")
  flush.console()
  Sys.sleep(1)
}

cat("Done!\n")

# Read file contents
content <- readChar(fileIn, file.info(fileIn)$size)
cat("Contents of csv input:\n")
cat(content, "\n")

# Final output
biab_output("length", nchar(content))
