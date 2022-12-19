
pacman::p_load(tidyverse, csvwr)


tp_csv <- read_csv("data/10_ToxPi/NAS_toxpi_subscale-allinone-08-09-22.csv", n_max = 100)

str(tp_csv)

# create a basic table schema using the dataframe
s <- derive_table_schema(tp_csv)

# add the schema to a list along with the url and notes
tb <- list(url = "data/10_ToxPi/NAS_toxpi_subscale-allinone-08-09-22.csv", 
           tableSchema = s,
           notes = "version 1.0 of ToxPi outputs across all domains")

# create the metadata by listing all table lists to be included
m <- create_metadata(tables = list(tb))

# convert to json and take a look
j <- jsonlite::toJSON(m)
jsonlite::prettify(j)
