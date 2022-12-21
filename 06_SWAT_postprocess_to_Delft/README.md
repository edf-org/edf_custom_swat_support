# Description

Script to turn csv outputs of SWAT discharge and flow data into the .dis text format required for Delft3D.

# Process

The .dis file is weird.. It's a number of repeating sections per subbasin, with a section each for discharge and yield. 

Sample:

> table-name           'Discharge : 1'  
> contents             'regular   '  
> location             '215                 '  
> time-function        'non-equidistant'  
> reference-time       20080815  
> time-unit            'minutes'  
> interpolation        'linear'  
> parameter            'time                '                     unit '[min]'  
> parameter            'flux/discharge rate '                     unit '[m3/s]'  
> records-in-table     47  
>  0.0000000e+000  5.8750000e+000  
>  1.4400000e+003  3.2350000e+001  
>  2.8800000e+003  2.2330000e+002  
>  4.3200000e+003  1.9480000e+002  
>  ...........  


Each section has its own header which describes the data below it. The `01_SWAT_to_Delft_text.R` script just loops through each subbasin in the input SWAT data and creates both a new block of header text and re-formatted SWAT data to add to the .dis file.

It does this once for discharge data and once more for yield data, so that the .dis file ends up as discharge data per subbasin followed by yield data per subbasin.

### Headers
There are a number of lines of the header which are dynamic:
* 1: the number of the table in the .dis file
* 3: the location, which is just the subbasin ID for discharge data (e.g. 286), or the subbasin id suffixed with a Y for yield data (e.g. 286Y)
* 5: reference time, which is the start date for the data time period
* 10: n records in table

`src/functions.R` contains some helper functions which take the dynamic field and appends it to the header line, so they can be combined to create the subbasin specific header block.

### Data
There are two data fields underneath the header:
>  1.9036800e+006  3.1180000e-004   

The first is the time in minutes from the reference time, and the second is the discharge or yield at that point in time. Both are formatted in scientific notation.

After the header block is created for a subbasin, the script loops through each line of data for that subbasin and reformats the datetime to minutes from reference time, and combines it with the reformatted discharge or yield data.