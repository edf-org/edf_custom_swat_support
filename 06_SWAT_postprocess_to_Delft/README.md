# Description

Script to turn csv outputs of SWAT discharge and flow data into the .dis text format required for Delft3D.

# Process

The .dis file is weird.. It's a number of repeating sections per subbasin, with a section each for discharge and yield. 

Sample:

> table-name           'Discharge : 1'
contents             'regular   '
location             '215                 '
time-function        'non-equidistant'
reference-time       20080815
time-unit            'minutes'
interpolation        'linear'
parameter            'time                '                     unit '[min]'
parameter            'flux/discharge rate '                     unit '[m3/s]'
records-in-table     47
 0.0000000e+000  5.8750000e+000
 1.4400000e+003  3.2350000e+001
 2.8800000e+003  2.2330000e+002
 4.3200000e+003  1.9480000e+002
...........


Each section has its own header describing the data below it. This script simply loops through each subbasin in the input SWAT data, edits the dynamic fields in the header text