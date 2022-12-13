# Description

This repo stores the various scripts used to process facility locations in the Healthy Gulf project.

There are three steps to the process:

1. Geocode to improve location data for facilities
2. Match facility locations to land parcels
3. Match land parcels to study area raster template grid cells and create final facility to grid cell lookup

Each of these steps is carried out in a separate R script, and the process is described in more detail in the accompanying .md docs.

The process here also incorporates some extra facility data which was added to the original project facility data in November 2022, so the first script largely treats those facilities separately and merges them with the original data. And at some other points there are separate steps to assess the impact of adding these facilities in.


## Key files

| file name | description |
| --- | --- |
| `output/facilities/facilities_all_coded_2022-12-08.csv` | The combined list of all 1,244 facilities and their locations. This includes original facilities, geocoded by RJ, and new facilities sourced by Cloelle in Nov 2022. Find an overview of key fields in `01_geocode_and_merge.md`. |
| `output/facilities/facility_parcel_lookup_2022-12-13.csv` | Lookup table which links facilities to their matched land parcels and the uncertainty_class which scores the quality of the matches. |
| `output/facilities/facility_grid_lookup_2.0_2022-12-13.csv` | Lookup table which links facilities to the raster template grid cells that they cover and also describes the % of the grid cell covered by those facilities (based on the facility to parcel links). |