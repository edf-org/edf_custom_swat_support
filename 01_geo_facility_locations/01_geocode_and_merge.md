## Document purpose

Describe the data processing carried out in Nov. 2022 to add in further facilities to the current list.

## Inputs

| Filename | short name | Description | n facilities |
| --- | --- | --- | --- |
| facilities_v2021Jul28_HUC8pts.shp | facilities_orig | Facilities data after a few inital stages of processing. Namely, combining from different data sources, and geocoding steps carried out by RJ at TAMU. | 946 unique REGISTRY_ID |
| PROGbyFRS_uniq_11-21-22.csv | facilities_new | An additional list of facilities sourced by Cloelle. There is some overlap with the inital data | 1402 unique REGISTRY_ID |

## Steps

### Identify overlaps

`facilities_new` contains:

- 833 facilties which exist in `facilities_orig` . These will be discarded
- and 569 facilities which DO NOT exist in `facilities_orig` . Referred to as `facilities_new_clip`, these will be location checked and then merged with `facilities_orig`.

Of the 569 facilites in `facilities_new_clip`, 83 have missing lat & lon.

### Geocoding

The Google geocoding API was used to find address information and lat & lon for the 83 facilities, using a combination of the `LOCATION_ADDRESS` and `POSTAL_CODE` fields from `facilities_orig`. 

This was successful for 81 facilities, but errored for 2 where the input address data was not good enough.

The google API also gives an indication of the quality of the location result:

- `"ROOFTOP"` indicates that the returned result is a precise geocode for which we have location information accurate down to street address precision.
- `"RANGE_INTERPOLATED"` indicates that the returned result reflects an approximation (usually on a road) interpolated between two precise points (such as intersections). Interpolated results are generally returned when rooftop geocodes are unavailable for a street address.
- `"GEOMETRIC_CENTER"` indicates that the returned result is the geometric center of a result such as a polyline (for example, a street) or polygon (region).
- `"APPROXIMATE"` indicates that the returned result is approximate.

Just 37 (45%) of the 83 facilities return the most precise location, and caution should be extended towards the others.

| location_type | n |
| --- | --- |
| APPROXIMATE | 12 |
| GEOMETRIC_CENTER | 24 |
| RANGE_INTERPOLATED | 8 |
| ROOFTOP | 37 |
| NA | 2 |

### Merging

Lat & lon data from the geocoding was added into the facilties data for `facilities_new_clip`, and then this data was combined with `facilities_orig` to give a total of **1,515 facilities**.

This extended list is saved as: `output/facilities/facilities_all_coded_2022-11-23.csv`

********************Key fields********************

A number of fields have been added to this file to try and make the provenance of both the facilities data and the location information (lat & lon) clear.

Descriptions below. ‘existing’ indicates the field was present in `facilities_orig`

| Field name | new? | Description |
| --- | --- | --- |
| REGISTRY_ID | existing | Identifier for facility |
| lat_merge | existing | I think from RJ’s processing. This has been updated to include lat from facilities_new_clip where present. |
| lon_merge | existing | I think from RJ’s processing. This has been updated to include lon from facilities_new_clip where present. |
| edf_source | new | To describe whether the data comes from facilities_orig or facilities_new. Refers to input filenames. |
| latlon_merge_src | new | To make clear where the data in the combined lat_merge and lon_fields has come from - either facilities_orig , facilities_new, or geocoding. |
| GC_ …  | new | This suffix denotes data from the geocoding of facilities_new data, so is only present for 83 records.  |

## Location checks

Facility points falling at the same location is an existing problem in the `facilities_orig` data. There are 80 facilities out of the 946 total (8%) which are at the same location as another one. Usually this is just two at the same point, but there are two instances of three at the same point:

| n facilites at a single location | count of facilities |
| --- | --- |
| 2 | 74 |
| 3 | 6 |

The same problem exists in the `facilities_new_clip` data (post-geocoding), with 66 of the 569 (12%) overlapping with another.

In most instances this seems to be facilities with slightly different names but very similar or identical address information. Some examples:

| REGISTRY_ID | PRIMARY_NAME | LOCATION_ADDRESS | geometry | dupe count |
| --- | --- | --- | --- | --- |
| 110022523991 | MIDSTREAM FUEL SERVICE LLC (SABINE PASS) | 7680 S  FIRST AVE | c(-93.86733, 29.72075) | 2 |
| 110034484476 | SABINE PASS TERMINAL | 7680 S FIRST AVE | c(-93.86733, 29.72075) | 2 |
| 110007206095 | SIGNAL INTERNATIONAL TEXAS NORTH YARD | 2350 S GULFWAY DR | c(-93.93285, 29.89453) | 2 |
| 110070261730 | GT LOGISTICS GULFWAY TERMINAL | 2350 GULFWAY DR | c(-93.93285, 29.89453) | 2 |
| 110017836699 | DERRICK OIL & SUPPLY | 1349 AUSTIN AVENUE | c(-93.94348, 29.87758) | 3 |
| 110070070487 | RELADYNE - PORT ARTHUR AUSTIN | 1349 AUSTIN AVE | c(-93.94348, 29.87758) | 3 |
| 110070239253 | RELADYNE | 1349 AUSTIN AVE | c(-93.94348, 29.87758) | 3 |

The problem is only slightly exacerbated by new overlaps when the two datasets are merged. `facilities_all_coded_2022-11-23.csv` contains 163 facilities out of the 1,515 (11%) which share a location with another.

| n facilites at a single location | count of facilities |
| --- | --- |
| 1 | 1350 |
| 2 | 134 |
| 3 | 24 |
| 5 | 5 |

(note - sum here of 1,513 excludes the two facilities with no location info)

A table of all facilities which share a location is saved in `output/facilities/facilities_duplicated_locations.csv`