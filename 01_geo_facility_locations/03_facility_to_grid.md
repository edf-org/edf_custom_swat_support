# Facility > parcel > grid

## Starting point:

`facility_parcel_lookup_2022-12-08.csv`: Lauren’s lookup between facilities and their matched land parcels 

n rows = 5319

n unique facilities (registry_id) = 940

n unique parcels (Stone_Unique_ID_revised) = 4,841

n parcels with no matched facility (industrial land) = 2,333

`parcels_lookup_only_20221208.gpkg`. Spatial data for land parcels in Houston area, restricted to only those parcels identified in Lauren’s lookup

Note: there are some instances of overlapping geometries in this data, of two types:

- duplicated, i.e. where identical polygons exist for multiple records. These exist because there can be multiple owners recorded for the same land parcel. So where we link a facility to multiple identical parcels we’ll just take the extent of the parcels.
- overlapping, i.e. where parcels of different sizes sit on top of each other. These exist because of more complex ownership aspects, for example where a large parcel might have been split up between owners but the inital overall parcel hasn’t been corrected. In these instances we may be overestimating coverage by taking the extent of all linked parcels, but this can be controlled to some extent by the uncertainty_class, which will make the quality of matching clear.

## Process:

1. Intersect parcel shapefile with grids, to get a spatial lookup between *Stone_Unique_ID_revised* and *grid_id.* The diagram below shows two example grid cells (with the *grid_id* in the centre) and the parcels which intersect them, coloured by their parcel identifier (*Stone_Unique_ID_revised*). So parcels which cross multiple grids end up with multiple rows in the table, which also describes the % area of the parcel which is in each grid cell. 
    
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
    
    n distinct parcels = 5,469
    
    n distinct grid cells = 48,626
    
2. Join `parcel_grid_lookup` table with `facility_parcel_lookup` (by *Stone_Unique_ID_revised*) to get a table linking the facility (*registry_id*) to grid cells (*grid_id)*.
3. Create a new identifier which accounts for parcels with no matched facility. *registry_stone_id* is the *registry_id* wherever it exists, else it’s the *Stone_Unique_ID_revised.*

4. Spatially union overlapping polygons of parcels in the same grid cell, in order to accurately work out the % area of each grid covered by a facility and uncertainty class.

    a. This is necessary because some facilities are linked to land parcels (with the same uncertainty class) which overlap in the same grid cell. So grouping by the *registry_stone_id*, *grid_id* and *uncertainty_class* to calculate the % area covered of each linked grid cell results in some grid cells having coverage > 100%.

    b. The example below shows the parcel data for registry_id: 110000495241, which is linked to multiple parcels (Stone_Unique_ID_revised: 73243, 101046, 119821)
        
    ![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/b5d88405-353c-490d-a6c1-bad1905d8ae8/Untitled.png)
        
    c. Grouping by the three IDs we’re concerned with and dissolving the geometries within the grid results in geometries like this (using the same example as above):
        
    ![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/8c49243b-920a-4ece-9549-cef8f059acfb/Untitled.png)
        
    d. This means for each facility we can see the combined % grid cell coverage of all parcels its linked to by different uncertainty class matches
5. Export final table

## End point

`facility_grid_lookup_1.0.csv`

n rows = 74,225

n distinct facilities or industrial parcels (*registry_stone_id*) = 3,279 (940 facilities + 2,333 industrial parcels + 6 facilities not matched to parcels)

n distinct grid cells = 43,067

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

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/cb37be9a-a1ab-43d2-9b4a-c0a0b114464e/Untitled.png)

## Lookup overview

Lauren’s matching quality classes:

| uncertainty_class | description |
| --- | --- |
| 1.0 | Direct location match with industrial parcel.  Highest confidence of petrochemical interest. |
| 2.0 | Direct location match with commercial or vacant land parcel. Could be gas station or legacy facility. May be of  petrochemical interest. |
| 3.0 | Direct location match with other parcel (not industrial, commercial, or vacant) e.g. residential or exempt. May be of petrochemical interest. |
| 4.1 | No direct location match. Industrial parcel within 100 m of point. Facility location data may be inaccurate. May be of petrochemical interest. |
| 4.2 | No direct location match. Commercial or vacant land parcel within 100 m of point. Could be gas station or legacy facility. May be of petrochemical interest. |
| 4.3 | No direct location match. Only other parcel classes (not industrial, commercial, or vacant) e.g. residential or exempt within 100 m. Facility least likely to be of petrochemical interest and/or most likely to have inaccurate location data. |
| 5.0 | Industrial land. No facility points within 100 m. Chemical data will be missing but chemical release potential exists. Will need manual checks if these areas show severe flood risk. |

Count of facilities, grid cells and area covered by the different uncertainty classes:

| uncertainty_class | n_facilities | n_grid_cells | total_area_km_2 |
| --- | --- | --- | --- |
| 1.0 | 317 | 12358 | 80.2 |
| 2.0 | 350 | 3442 | 17.4 |
| 3.0 | 146 | 6676 | 43.5 |
| 4.1 | 43 | 2823 | 17.6 |
| 4.2 | 107 | 2208 | 10.4 |
| 4.3 | 125 | 8002 | 47.8 |
| 5.0 | 2333 | 38710 | 212.3 |
| 6.0 | 6 | 6 | 0.1 |

## Chemical weighting by area

Need to take checmical hazard data from points to parcel and then grid.

![Untitled](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/601b94e2-8588-47ed-8170-641215d8db27/Untitled.png)