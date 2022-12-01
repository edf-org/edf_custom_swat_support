

# extract time in minutes between reference time and new time
timeToMinutes <- function(ref_time, new_time){
  interval(ref_time, new_time) / minutes(1)
}


# insert extra leading "0" in exponent part of scientific notation 
sciPad0 <- function(num_char){
  
  str_flatten(c(substring(num_char, 1, 11), 
                "0", 
                substring(num_char, 12, 14)))
}


# extract date and flow from input table and return as text string with numbers in scientific notation
dfToText <- function(df, row){
  
  text_time <- formatC(timeToMinutes(ref_time, df[[row, "datestamp"]]), format = "e", digits = 7)
  text_discharge <- formatC(df[[row, "value"]], format = "e", digits = 7)
  
  paste0(" ", sciPad0(text_time), "  ", sciPad0(text_discharge))
}


# EDIT HEADER LINES FOR SPECIFIC DATA

# append subbasin number on to header line 1 and return correctly formatted text string
hL1Append <- function(num){
  
  str_flatten(c(header_lines[1],
                as.character(num),
                "'"))
}

str_count(paste0(as.character(225), "Y"))

# append number to header line 3 and return correctly formatted text string
hL3Append <- function(num, yield_char){
  
  # padding spaces is 20 minus character length of number
  n_pad <- 20 - str_count(paste0(as.character(num), yield_char))
  
  # new string from header line, text number and padding
  str_flatten(c(header_lines[3], as.character(num), yield_char, rep(" ", n_pad), "\'"))
}

# append start date of data to header line 5
hL5Append <- function(ref_time){
  
  str_flatten(c(header_lines[5], format(ref_time, "%Y%M%d")))
}


hL10Append <- function(data_length){
  
  str_flatten(c(header_lines[10], data_length))
}


