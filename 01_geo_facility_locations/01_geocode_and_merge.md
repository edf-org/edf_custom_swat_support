# Facility data merging & gecoding

## Document purpose

Describe the data processing carried out in Nov. 2022 to add in further facilities to the current list.

## Inputs

| Filename | short name | Description | n facilities |
| --- | --- | --- | --- |
| facilities_20220311.csv | facilities_orig | Facilities data after a few inital stages of processing. Namely, combining from different data sources, and geocoding steps carried out by RJ at TAMU. Improved location data for facilities (saved in the ‘Latitude’ and ‘Longitude’ fields) was created by running all facility addresses through Google’s geocoding API | 946 unique REGISTRY_ID |
| PROGbyFRS_uniq_11-21-22.csv | facilities_new | An additional list of facilities sourced by Cloelle. There is some overlap with the inital data | 1402 unique REGISTRY_ID |

## Steps

### 1. Identify overlaps

`facilities_new` contains:

- 833 facilties which exist in `facilities_orig` . These will be discarded
- and 569 facilities which DO NOT exist in `facilities_orig` . Referred to as `facilities_new_clip`, these will be location checked and then merged with `facilities_orig`.

Of the 569 facilites in `facilities_new_clip`, 83 have missing lat & lon.

### 2. Geocoding

The Google geocoding API was used to find address information and lat & lon for all 569 new facilities, using a combination of the `LOCATION_ADDRESS` and `POSTAL_CODE` fields from `facilities_orig`.  `POSTAL_CODE` was shortened to just the first 5 digits.

Successful results for all but two facilities, which just seem to have nonsense addresses (e.g. “FROM ALVIN GO S ON HWY 35 FOR 7 MI UNTIL THE HWY I”, “2.5 MI. N. OF HIGHLAND ON S.H. 124”)

The google API also gives an indication of the [quality of the location result](https://developers.google.com/maps/documentation/geocoding/requests-geocoding#results):

- `"ROOFTOP"` indicates that the returned result is a precise geocode for which we have location information accurate down to street address precision.
- `"RANGE_INTERPOLATED"` indicates that the returned result reflects an approximation (usually on a road) interpolated between two precise points (such as intersections). Interpolated results are generally returned when rooftop geocodes are unavailable for a street address.
- `"GEOMETRIC_CENTER"` indicates that the returned result is the geometric center of a result such as a polyline (for example, a street) or polygon (region).
- `"APPROXIMATE"` indicates that the returned result is approximate.

Breakdown for the geocoding results:

| location_type | n | pct |
| --- | --- | --- |
| APPROXIMATE | 45 | 8% |
| GEOMETRIC_CENTER | 102 | 18% |
| RANGE_INTERPOLATED | 48 | 8% |
| ROOFTOP | 372 | 65% |
| NA | 2 | 0% |

For the new facilities which already had location data (486 of 569) we can calculate the distance between the original points and the new ones from geocoding. For 6 facilities, the point has jumped more than 60km, which seems dubious. But the majority (93%) are under 10km. For comparison, the study area is (very roughly) 150x100km.

![post-geocoding.png](figs/fig%20-%20facility%20point%20movement%20post-geocoding.png)

### 3. Intersect with study area

Limiting the geocoded results to those just within the study area gives **298 facilities**.

### 4. Merging

The new lat & lon data from the geocoding was added into the facilties data for `facilities_new_clip`, and then this data was combined with `facilities_orig` to give a total of **1,244 facilities**.

This extended list is saved as: `output/facilities/facilities_all_coded_2022-12-07.csv`

********************Key fields********************

A number of fields have been added to this file to try and make the provenance of both the facilities data and the location information (lat & lon) clear.

Descriptions below. ‘existing’ indicates the field was present in `facilities_orig`

| Field name | new? | Description |
| --- | --- | --- |
| REGISTRY_ID | existing | Identifier for facility |
| Latitude | existing | This is the updated location from RJ’s initial geocoding. This has been updated to include lat from facilities_new_clip where present. |
| Longitude | existing | This is the updated location from RJ’s initial geocoding. This has been updated to include lon from facilities_new_clip where present. |
| fac_source | new | To describe whether the data comes from facilities_orig or facilities_new. Refers to input filenames. |
| latlon_src | new | To make clear where the data in the Latitude and Longitude fields has come from - either facilities_orig (and RJ’s geocoding), or facilities_new_clip (and my run of geocoding). |
| GC_ …  | new | This suffix denotes data from the geocoding of facilities_new_clip data, so is present for 298 records. |

## Location checks

Facility points falling at the same location is an existing problem in the `facilities_orig` data. 80% of facility points are the only one at that location, but the other 20% have some overlap with one or more other facility records.

| n facilites at a single location | n | pct |
| --- | --- | --- |
| 1 | 759 | 80% |
| 2 | 148 | 16% |
| 3 | 18 | 2% |
| 4 | 20 | 2% |

This problem is exacarbated slightly once the new facilities are added in, with just 72% of facilities being the only one at that location:

| n facilites at a single location | n | pct |
| --- | --- | --- |
| 1 | 900 | 72% |
| 2 | 238 | 19% |
| 3 | 48 | 4% |
| 4 | 52 | 4% |
| 5 | 5 | <0% |

Some examples of the facilities with many overlaps shows different names with very similar address info.

| REGISTRY_ID | PRIMARY_NAME | LOCATION_ADDRESS | ZIP_CODE | geometry | n_fac_overlaps |
| --- | --- | --- | --- | --- | --- |
| 110000506079 | EQUISTAR CHEMICALS BAYPORT CHEMICALS PLANT | 5761 UNDERWOOD ROAD | 77507 | c(-95.0796976, 29.6260882) | 4 |
| 110015743720 | OCCIDENTAL CHEMICALS PLANT | 5761 UNDERWOOD RD. | 77507 | c(-95.0796976, 29.6260882) | 4 |
| 110045433090 | SUNOCO BAYPORT BPT1 | 5761 UNDERWOOD RD | 77507 | c(-95.0796976, 29.6260882) | 4 |
| 110067200460 | SOLVAY USA INC. |  | 77507 | c(-95.0796976, 29.6260882) | 4 |
| 110069449270 | INEOS POLYMERS | 1230 INDEPENDENCE PKWY S | 77571 | c(-95.089072, 29.7191601) | 4 |
| 110070082913 | GEMINI HDPE LLC - LA PORTE PLANT | 1230 INDEPENDENCE PARKWAY SOUTH | 77571 | c(-95.089072, 29.7191601) | 4 |
| 110070158362 | GEMINI HDPE UNIT | 1230 INDEPENDENCE PKWY S STE 4 | 77571 | c(-95.089072, 29.7191601) | 4 |
| 110070864284 | INEOS POLYETHYLENE | 1230 INDEPENDENCE PARKWAY, S. | 77571 | c(-95.089072, 29.7191601) | 4 |