
BEGIN {
  FS = OFS = "	"

  
    split("Setophaga fusca", speciesValues, "	")
    for (i in speciesValues) species[speciesValues[i]] = 1
  
    split("CO", countryValues, "	")
    for (i in countryValues) countries[countryValues[i]] = 1
  
  
  
}
{
  keep = 1

  # filters
  
  if (keep == 1 && ($7 in species)) {
    keep = 1
  } else {
    keep = 0
  }

  
  if (keep == 1 && ($17 in countries)) {
    keep = 1
  } else {
    keep = 0
  }

  
  
  
  
  if (keep == 1 && ($30 >= -75.967410120046 && $30 <= -74.584490120046 && $29 >= 4.75318151051837 && $29 <= 5.82418151051836)) {
    keep = 1
  } else {
    keep = 0
  }

  
  
  
  
  
  
  
  if (keep == 1 && ($35 == "Stationary" || $35 == "Traveling")) {
    keep = 1
  } else {
    keep = 0
  }

  
  
  
  
  
  
  if (keep == 1 && ($42 == 1)) {
    keep = 1
  } else {
    keep = 0
  }

  

  # keeps header
  if (NR == 1) {
    keep = 1
  }

  if (keep == 1) {
    print $0
  }
}

