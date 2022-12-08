# 02 Facility to parcel

## Document purpose

Describe the steps taken to match facility locations to land parcels and flag the quality of the matches in a field called uncertainty_class.

## Inputs

| file name | description |
| --- | --- |
| `facilities_all_coded_2022-12-08.csv` | The combined list of all facility locations |
| `Parcels_Revised_wLookup.gdb` | Geodatabase of land parcels created by Stone Environmental after their processing |

## Steps

### 1. Reduce size of parcels data

This is just to create a smaller, more manageable file to use in R for flagging uncertainty classes.

All land parcels with a stat_land_combined == “F2” or which are within 100m of a facility were exported using QGIS, and saved in the file: `parcels_revised_facilities100m_industrial_Dec22.gpkg`

### 2. Spatial joins of facilities and parcels

The table below describes the definition for each uncertainty class.

| uncertainty_class | parcel land use codes | description |
| --- | --- | --- |
| 1.0 | F2 | Direct location match with industrial parcel.  Highest confidence of petrochemical interest. |
| 2.0 | C1, C2, C3, C4, F1 | Direct location match with commercial or vacant land parcel. Could be gas station or legacy facility. May be of  petrochemical interest. |
| 3.0 | All other | Direct location match with other parcel (not industrial, commercial, or vacant) e.g. residential or exempt. May be of petrochemical interest. |
| 4.1 | F2 | No direct location match. Industrial parcel within 100 m of point. Facility location data may be inaccurate. May be of petrochemical interest. |
| 4.2 | C1, C2, C3, C4, F1 | No direct location match. Commercial or vacant land parcel within 100 m of point. Could be gas station or legacy facility. May be of petrochemical interest. |
| 4.3 | All other | No direct location match. Only other parcel classes (not industrial, commercial, or vacant) e.g. residential or exempt within 100 m. Facility least likely to be of petrochemical interest and/or most likely to have inaccurate location data. |
| 5.0 | F2 | Industrial land. No facility points within 100 m. Chemical data will be missing but chemical release potential exists. Will need manual checks if these areas show severe flood risk. |

********************************Matching process********************************

- Facility points were directly intersected with the land parcels to find matches of class 1, 2 or 3.
- Remaining facilities (without a match) were then buffered by 100m, and intersected again with the parcels data to find matches of class 4.1, 4.2, or 4.3
- Finally, all remaining industrial parcels without a matched facility were flagged as class 5.

This final lookup file is saved as: `output/facilities/facility_parcel_lookup_2022-12-08.csv`.

The table below is a summary of the number of facilities and matched parcels for each uncertainty_class, along with the % increase in facilities from the additions to the facility list.

| uncertainty_class | facilities | parcels | n records | % extra facilities |
| --- | --- | --- | --- | --- |
| 1 | 411 | 498 | 873 | 30% |
| 2 | 443 | 416 | 456 | 27% |
| 3 | 210 | 207 | 255 | 44% |
| 4.1 | 62 | 110 | 145 | 44% |
| 4.2 | 146 | 626 | 758 | 36% |
| 4.3 | 177 | 1186 | 1393 | 42% |
| 5 | NA | 2486 | 2486 | 0% |

Note: the no. of records per class is larger than the count of facilities and parcels as the same facility can be matched to multiple parcels within a class (due to overlapping parcels, or the effect of the facility buffering for class 4), or the same parcel can be matched to multiple parcels (due to different facility records with identical or close locations, or the effect of facility buffering for class 4).

The same facility can have multiple matches across classes 1-3, or 4.1-4.3, but no facilities are in both of these groups.

## Comparison with original matching

More parcels are matched than from the original processing done by Lauren because of the addition of new facilities. However, comparing directly between just the facilities from `facilities_20220311.csv` shows a few extra facilities are matched in this process, and just two are lost.

**********************************************************In new lookup but not in old:**********************************************************

This is a count of the records in the new lookup which don’t match on registry_id and uncertainty_class to records in the original lookup.

| uncertainty_class | stat_land_comb | n parcels |
| --- | --- | --- |
| 3 | NA | 5 |
| 4.2 | C3 | 12 |
| 4.3 | NA | 3 |
| 5 | F2 | 312 |

Extract of these saved as: `output/facilities/facility_parcel_lookup_new_not_old.csv`

I can’t work out why these weren’t in original matching. There don’t seem to be any records with uncertainty_class = 4.2 and stat_land_comb = “C3” in the original lookup so I wonder if this field might have been missed in a query. 

class 3 and 4 differences are really minor, but there are a lot more industrial parcels included - perhaps Lauren’s industrial parcels were limited to study area whereas I’ve just pulled all from the .gdb?

****************************************************In old lookup but not new:****************************************************

This is a count of records which don’t match on registry_id and uncertainty_class to records in the new lookup. All of these records are actually in the new lookup but have a different class.

| uncertainty_class | parcels |
| --- | --- |
| 1 | 1 |
| 2 | 1 |
| 5 | 159 |

The class 1 and 2 parcels included here but not in the new lookup both have NA values for land_use_comb in the parcel data I’m using, so not sure why they were in the old one. The facilities are included in the new lookup as class 3 matches.

The class 5 parcels here are all in the new lookup matched as class 1 or 4.1 to the new facilities which were added to the facilities list.

File of these records saved as: `output/facilities/facility_parcel_lookup_old_not_new.csv`