# Description

> Note: these scripts use some helper functions to convert between csv and raster formats. These can be found in `src/functions.R`.

Scripts in this folder cover the following areas:

### 1. Processing ToxPi inputs

Inputs are the individual datasets to feed into ToxPi, which together cover different domains. These come from a range of different sources and are in a number of different formats (e.g. shapefiles, csvs, raster).

The aim of these processing steps is to transform each input dataset to a common format: the [raster template](../02_geo_raster_template/) created for the study area. This way all data will be referencing a common spatial index and the ToxPi process will be able to combine each domain to get a composite score.

The input datasets for different domains can be found in `data/ToxPi_inputs`. The file `data/CVI for Gulf_2 - csv 2022_07_04.csv` records key information for each file, as well as some notes on processing steps.

Each `01_ToxPi_inputs_... .R` script processes datasets in different domains. A brief overview of the approach for each domain:

| Domain | Input file format | Steps |
| --- | --- | --- |
| Social | Largely shapefiles at census tract level, some misc other formats | Rasterise polygon shapefiles, and some custom steps for redlining and medically underserved datasets.  `CVI for Gulf_2 - csv 2022_07_04.csv` is used as a lookup file to loop through and process all datasets. |
| Ecosystem | Raster data at a slightly different resolution and projection to raster template | Warp to fit raster template |
| Delft3D | Raster files covering small subsets of the study area, at slightly different resolution and projection to raster tempate | Warp to fit raster template, and combine into single file |
| SWAT | Shapefiles at subbasin level | Rasterise polygon shapefiles |

All processed inputs are saved in `output/ToxPi_inputs_processed/`. There are individual files for each domain, but all should have the raster template `cell_id` field as a common, unique index.

### 2. Processing ToxPi outputs

ToxPi outputs are the csv files created by running input datasets through ToxPi. Each should use `cell_id` as an index, and other fields will be an overall score, or scores for Domains or sub-domains.

The `02_ToxPi_outputs... .R` script takes the csv output file and saves each score field as a separate raster file, which can be visualised on a map. These files are saved in `output/ToxPi_outputs_processed/`.

> Note - for the csv outputs from the facility ToxPi, cell_id should not be distinct because the same cell can have a score for more than one uncertainty_class. This means the output table needs to be restricted to just one uncertainty class before converting to raster (or made distinct by cell_id some other way). I haven't added this to the script as we don't have a final facilities ToxPi output file with uncertainty_class yet. But it should be straightforward to add a line to `02_ToxPi_output_to_raster.R` to filter by uncertainty_class before converting.


### 3. Visualising ToxPi outputs

Some dashboards have been made to allow interactive visualisation of the raster ToxPi output, using the R package [flexdashboard](https://rstudio.github.io/flexdashboard/). This package uses R Markdown to wrap different components into a simple html dashboard (see [here](https://rstudio.github.io/flexdashboard/articles/flexdashboard.html) for some basic, minimal examples). In this case, [Leaflet for R](https://rstudio.github.io/leaflet/) is used to add the raster layers to a map where they can be toggled on and off.

There are two main dashboards:

1. ToxPi receptors outputs - covering the whole study area
2. ToxPi facilities outputs - covering facility areas

I've also created a simple minimal example, with just one leaflet map rather than multiple tabs, which hopefully will be easiest to reproduce and update with different datasets.

> Note: there is a funny flexdashboard issue I've run into, which occurs when trying to knit the final document. The error is something like "Error in tempfile.. temporary name too long", and seems to be caused by the very long file paths resulting from running a script within a onedrive directory (e.g. `C:\Users\username\OneDrive - Environmental Defense Fund - edf.org\GCA Work\edf_custom_swat_support\08_ToxPi_data_processing\dashboard_script.rmd`). The workaround is just to copy the script to a local directory with a shorter file path and run it there instead.

To generate the html dashboard, open the `.RMD` file in RStudio, update the two file paths to point at the raster file you want to map, and the facilities data, then hit knit:

![Rmd knit screengrab](figs/screengrab%20-%20knit%20flexdashboard.png)