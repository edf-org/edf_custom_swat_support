# Facility to grid

## Document purpose

Describe the steps taken to match facility locations to grid cells of the raster template for the study area.

The result is a lookup file between facility (using registry ID or the stone unique land parcel ID for industrial land parcels), uncertainty class, and raster template cell ID. This lookup will be used for the facility ToxPi.

## Inputs

| file name | description |
| --- | --- |
| `facility_parcel_lookup_2022-12-08.csv` | The lookup between facilities and land parcels created in `02_facility_to_parcel.R`. The identifier registry_stone_id in this file is either the registry_id (for facilities) and Stone_Unique_ID_revised for the unlinked industrial land parcels included). |
| `parcels_lookup_only_20221208.gpkg` | Land parcel data from the parcels .gdb, but restricted to just parcels which are in the lookup file. This smaller file is used here just to speed up the spatial joining in R. |
| `raster_template.tif` | The raster file covering the study area in a 100x100m grid. |

Note: the land parcel data contains some instances of overlapping geometries, of two types:

- duplicated, i.e. where identical polygons exist for multiple records. These exist because there can be multiple owners recorded for the same land parcel. So where we link a facility to multiple identical parcels we’ll just take the extent of the parcels.
- overlapping, i.e. where parcels of different sizes sit on top of each other. These exist because of more complex ownership aspects, for example where a large parcel might have been split up between owners but the inital overall parcel hasn’t been corrected. In these instances we may be overestimating coverage by taking the extent of all linked parcels, but this can be controlled to some extent by the uncertainty_class, which will make the quality of matching clear.

## Steps

1. Intersect parcel shapefile with grids, to get a spatial lookup between *Stone_Unique_ID_revised* and *grid_id.* 
The diagram below shows two example grid cells (with the *grid_id* in the centre) and the parcels which intersect them, coloured by their parcel identifier (*Stone_Unique_ID_revised*). So parcels which cross multiple grids end up with multiple rows in the table, which also describes the % area of the parcel which is in each grid cell. 
    
    ![parcel to grid diagram](figs/fig%20-%2003%20parcel%20to%20grid%20diagram.png)
    
    Table of a few example parcel IDs in above data:
    
    | Stone_Unique_ID_revised | grid_id | grid_area_pct |
    | --- | --- | --- |
    | 340977 | 2488795 | 0.54000232 |
    | 340977 | 2488796 | 0.36769929 |
    | 372521 | 2488795 | 0.10333346 |
    | 372521 | 2488796 | 0.05074277 |
    | 384670 | 2488795 | 0.23323661 |
    
    With this method, the parcels are joined to ANY grid cell they intersect with. If necessary we can use the areas to be more discerning about matches.
    
    
2. Join `parcel_grid_lookup` table with `facility_parcel_lookup` (by *Stone_Unique_ID_revised*) to get a table linking the facility (*registry_id*) to grid cells (*grid_id)*.

3. Spatially union overlapping polygons of parcels in the same grid cell, in order to accurately work out the % area of each grid covered by a facility and uncertainty class.

    a. This is necessary because some facilities are linked to land parcels (with the same uncertainty class) which overlap in the same grid cell. So grouping by the *registry_stone_id*, *grid_id* and *uncertainty_class* to calculate the % area covered of each linked grid cell results in some grid cells having coverage > 100%.

    b. The example below shows the parcel data for registry_id: 110000495241, which is linked by the same uncertainty class to multiple parcels (Stone_Unique_ID_revised: 73243, 101046, 119821)
        
    ![Untitled](figs/fig%20-%2003%20parcel%20to%20grid%20diagram%202.png)
        
    c. Grouping by the three IDs we’re concerned with and dissolving the geometries within the grid results in geometries like this, where facility 110000495241 is now just linked to all sections of grid cells which the three parcels covered:
        
    ![Untitled](figs/fig%20-%2003%20parcel%20to%20grid%20diagram%203.png)
        
    d. This means for each facility we can see the combined % grid cell coverage of all parcels its linked to by different uncertainty class matches
4. Export final table

## End point

`output/facilities/facility_grid_lookup_2.0_2022-12-08.csv`

n rows = 94,976

n distinct facilities or industrial parcels (*registry_stone_id*) = 3,730 (1,238 facilities + 2,486 industrial parcels + 6 facilities not matched to parcels)

n distinct grid cells = 48,269

This table describes:

- for each facility, based on the quality of parcel matches we’re interested in, the raster cells that cross any land parcel it has been matched to, and the % area of the raster cell covered by those matched land parcels.
- This same information for any industrial land parcels (described where *uncertainty_class* = 5)
- As well as the grid_ids that the lat & lon for 6 facilities which didn’t match to any parcel fall in to  (added with *uncertainty_class* = 6).

Example extract of table:

| registry_stone_id | grid_id | uncertainty_class | grid_area_pct |
| --- | --- | --- | --- |
| 340977 | 2488795 | 5 | 0.540 |
| 340977 | 2488796 | 5 | 0.368 |
| 384670 | 2488795 | 5 | 0.233 |
| 110032992563 | 2488795 | 2 | 0.103 |
| 110032992563 | 2488796 | 2 | 0.051 |
| 110070164942 | 2488795 | 2 | 0.103 |
| 110070164942 | 2488796 | 2 | 0.051 |

And that same data shown on the map (keeping the parcel boundaries in for illustrative purposes)

![Untitled](figs/fig%20-%2003%20parcel%20to%20grid%20diagram%204.png)

## Lookup overview

Count of facilities, grid cells and area covered by the different uncertainty classes:

| uncertainty_class | n_facilities | n_grid_cells | total_area_km_2 |
| --- | --- | --- | --- |
| 1 | 	411 | 	18,287 | 	123 | 
| 2 | 	443 | 	4,847 | 	25.2 | 
| 3 | 	210 | 	10,254 | 	63.3 | 
| 4.1 | 	62 | 	3,439 | 	21.5 | 
| 4.2 | 	146 | 	2,876 | 	14.4 | 
| 4.3 | 	177 | 	11,618 | 	75.7 | 
| 5 | 	2,486 | 	43,649 | 	240.8 | 
| 6 | 	6 | 	6 | 	0.1 | 

