import tabula
import pandas as pd

# URL from your prompt
url = "https://apps.who.int/gb/ebwha/pdf_files/WHA78/A78_22-en.pdf"


# Extract tables from the PDF (the scale is usually on specific pages)
tables = tabula.read_pdf(url, pages='all', multiple_tables=True)

# Convert the relevant table to a CSV
df = tables[0] # You may need to check which index contains the main scale
df.to_csv("scale_of_assessments.csv", index=False)