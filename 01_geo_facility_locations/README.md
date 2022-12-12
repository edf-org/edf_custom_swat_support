# Description

This repo stores the various scripts used to process facility locations in the Healthy Gulf project.

There are three steps to the process:

1. Geocode to improve location data for facilities
2. Match facility locations to land parcels
3. Match land parcels to study area raster template grid cells and create final facility to grid cell lookup

Each of these steps is carried out in a separate R script, and the process is described in more detail in the accompanying .md docs.

The process here also incorporates some extra facility data which was added to the original project facility data in November 2022, so the first script largely treats those facilities separately and merges them with the original data. And at some other points there are separate steps to assess the impact of adding these facilities in.