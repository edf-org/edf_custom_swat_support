# 02 Facility to parcel

## Document purpose

Describe the steps taken to match facility locations to land parcels and flag the quality of the matches in a field called uncertainty_class.

## Inputs

| file name | description |
| --- | --- |
| `facilities_all_coded_2022-12-08.csv` | The combined list of all 1,244 facilities and their locations. |
| `Parcels_Revised_wLookup.gdb` | Geodatabase of land parcels created by Stone Environmental after their processing. |

## Steps

### 1. Reduce size of land parcel data

This is just to create a smaller, more manageable file to use in R for flagging uncertainty classes.

All land parcels with a stat_land_combined == “F2” or which are within 100m of a facility were exported using QGIS, and saved in the file: `data/parcels/parcels_revised_facilities100m_industrial_Dec22.gpkg`

### 2. Spatial joins of facility points and land parcels

A number of classes have been decided to describe the quality of the match between a facility point, based on a combination of the distance between the facility point and land parcel (either 0 or up to 100m) and the land use of the matched parcel. The table below describes those classes, and the spatial joining itself is broken into steps based on the classes.

| uncertainty_class | parcel land use codes | description |
| --- | --- | --- |
| 1.0 | F2 | Direct location match with industrial parcel.  Highest confidence of petrochemical interest. |
| 2.0 | C1, C2, C3, C4, F1 | Direct location match with commercial or vacant land parcel. Could be gas station or legacy facility. May be of  petrochemical interest. |
| 3.0 | All other | Direct location match with other parcel (not industrial, commercial, or vacant) e.g. residential or exempt. May be of petrochemical interest. |
| 4.1 | F2 | No direct location match. Industrial parcel within 100 m of point. Facility location data may be inaccurate. May be of petrochemical interest. |
| 4.2 | C1, C2, C3, C4, F1 | No direct location match. Commercial or vacant land parcel within 100 m of point. Could be gas station or legacy facility. May be of petrochemical interest. |
| 4.3 | All other | No direct location match. Only other parcel classes (not industrial, commercial, or vacant) e.g. residential or exempt within 100 m. Facility least likely to be of petrochemical interest and/or most likely to have inaccurate location data. |
| 5.0 | F2 | Industrial land. No facility points within 100 m. Chemical data will be missing but chemical release potential exists. Will need manual checks if these areas show severe flood risk. |

**Matching process**

- Facility points were directly intersected with the land parcels to find matches of class 1, 2 or 3.
- Remaining facilities (without a match) were then buffered by 100m, and intersected again with the parcels data to find matches of class 4.1, 4.2, or 4.3
- Finally, all remaining industrial parcels without a matched facility were flagged as class 5.

This final lookup file is saved as: `output/facilities/facility_parcel_lookup_2022-12-08.csv`.

### Duplicate scenarios and approach
Because of the fact that facilities can be very close or at the same location, because parcels can overlap, and because of the 100m buffer approach to matching, there are a number of situations where facilities can be matched to multiple parcels, or vice versa. The points below describe each of those scenarios, and the approach to handle them taken in this processing:

1. Two or more unique facilities match the same parcel and have the same uncertainty class – this is okay, unique facility points can be close together and share a site.
2. One facility directly matches (i.e. facility is within parcel boundaries) multiple unique parcels with different land uses. In this situation the highest quality match is kept and the others discarded. So if a facility has matches of class 1 and class 3, only the class 1 match is kept.
3. One facility matches at a distance (i.e. facility within 100m of parcel boundary) multiple unique parcels with different land uses. In this situation all matches are kept, as the 100m buffer is a fuzzy match. So if a facility has matches of class 4.1 and 4.2 each match is kept.

## Lookup file summary

Five facilities from RJ's input data (`facilities_20220311.csv`) are outside the study area, and one is missing lat & lon data, so the number of remaining facilities that have been matched to parcels is 1,238.

n rows = 6,330
n unique facilities (registry_id) = 1,238
n unique parcels (Stone_Unique_ID_revised) = 5,441
n parcels with no matched facility (industrial land) = 2,486

The table below is a summary of the number of facilities and matched parcels for each uncertainty_class, along with the % increase in facilities from the additions to the facility list.

| uncertainty_class | facilities | parcels | n records | % extra facilities |
| --- | --- | --- | --- | --- |
| 1 | 411 | 498 | 873 | 30% |
| 2 | 440 | 415 | 453 | 27% |
| 3 | 185 | 180 | 222 | 45% |
| 4.1 | 62 | 110 | 145 | 44% |
| 4.2 | 146 | 626 | 758 | 36% |
| 4.3 | 177 | 1186 | 1393 | 42% |
| 5 | NA | 2486 | 2486 | 0% |

Note: the no. of records per class is larger than the count of facilities because of the scenarios described above where a facility can be matched to multiple parcels.


## Comparison with original matching

More parcels are matched than from the original processing done by Lauren because of the addition of new facilities. However, comparing directly between just the facilities from `facilities_20220311.csv` shows a few extra facilities are matched in this process, and just two are lost.

**********************************************************In new lookup but not in old:**********************************************************

This is a count of the records in the new lookup which don’t match on registry_id and uncertainty_class to records in the original lookup.

| uncertainty_class | stat_land_comb | n parcels |
| --- | --- | --- |
| 3 | NA | 2 |
| 4.2 | C3 | 12 |
| 4.3 | NA | 3 |
| 5 | F2 | 312 |

Extract of these saved as: `output/facilities/facility_parcel_lookup_new_not_old.csv`

class 3 and 4 differences are really minor, but there are a lot more industrial parcels included - the cause is possibly a slightly different version of the parcel data being used, as there were lot of iterations of the land use field based due to errors merging different data sources, and Lauren's process also had some extra filter steps.

****************************************************In old lookup but not new:****************************************************

This is a count of records which don’t match on registry_id and uncertainty_class to records in the new lookup. All of these records are actually in the new lookup but have a different class.

| uncertainty_class | parcels |
| --- | --- |
| 1 | 1 |
| 2 | 2 |
| 3 | 28 |
| 5 | 159 |

For the class 1 and 2 mis-matches, this seems to be due to slight variations in land_use type. For class 3, these are records which have been excluded from the new lookup because they have a class 1 or two match due to the new de-duping for class 1-3. And all the class 5 records here are industrial parcels which are in the new lookup but matched as either class 1 or 4.1 to the new facilities which were included.

File of these records saved as: `output/facilities/facility_parcel_lookup_old_not_new.csv`