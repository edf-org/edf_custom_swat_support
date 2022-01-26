
# Description

This repo stores the scripts for a google cloud function, which is used to transfer SWAT model outputs from a local machine to BigQuery tables, which enables further analysis and provides the data for a calibration dashboard.

The steps below outline how the process works.


# 1. Load model outputs into healthy_gulf bucket

Once the model has been run, outputs can be loaded into the **healthy_gulf** bucket using gsutil. Output files should be stored in the ‘**SWAT_outputs**’ directory, using separate sub-directories to distinguish between different model runs.

Example gsutil command:

```powershell
gsutil cp model_outputs/output* gs://healthy_gulf/SWAT_outputs/ModelRun1_monthly/
```

Any .rsv, .rch, .sed, or .vel output files in a subdirectory of ‘**SWAT_outputs**’ will be read and processed into a corresponding BigQuery table by a triggered [cloud function](https://console.cloud.google.com/functions/details/us-central1/swat_load_bq?project=edf-aq-data).

### Folder name

The name of the folder created for model outputs should contain two things: model information and the model time interval, in the following format:

> any_model_information_interval
> 

e.g. SWAT_outputs/model_run_1_monthly/

The name **must contain at least one underscore**, but can include as many as required. The word after the last underscore will always be taken as the time interval, and should be either ‘**monthly**’ or ‘**daily**’. This interval dictates how the script handles the files, and without it an error will be thrown.


### File formats

Two csv files holding configuration data used to process the files are also stored in the ‘**SWAT_outputs**’ bucket:

[file_metadata_headers.csv](https://console.cloud.google.com/storage/browser/_details/healthy_gulf/SWAT_outputs/file_metadata_headers.csv?pageState=(%22StorageObjectListTable%22:(%22f%22:%22%255B%255D%22))&project=edf-aq-data) - lists the field names contained in each file

[file_metadata_skips.csv](https://console.cloud.google.com/storage/browser/_details/healthy_gulf/SWAT_outputs/file_metadata_skips.csv?pageState=(%22StorageObjectListTable%22:(%22f%22:%22%255B%255D%22))&project=edf-aq-data) - lists the number of blank lines at the start of each file

In theory, these should make it easier to adjust for changes to file formats. However, once we start loading data into BQ it would be best if the field names don’t change



# 2. Check function execution

The logs of the cloud function can be checked using gcloud in powershell:

```powershell
gcloud functions logs read swat_load_bq --limit 30 --sort-by=[EXECUTION_ID,~TIME_UTC] 
```

Successful execution should produce a list of logs like so for each file:


LEVEL	NAME	        EXECUTION_ID	TIME_UTC		LOG
	    swat_load_bq	ldyuz4x54nto	25/01/2022	23:16.2	OpenBLAS WARNING - could not determine the L2 cache size on this system, assuming 256k 
I	    swat_load_bq	hlvyxqq77n1c	25/01/2022	20:47.0	File 'SWAT_outputs/file_metadata_skips.csv' loaded into bucket
I	    swat_load_bq	hlvyxqq77n1c	25/01/2022	20:47.0	 Loaded file type is not in SWAT_output folder or target file list, ignoring 
D	    swat_load_bq	hlvyxqq77n1c	25/01/2022	20:47.0	Function execution took 192 ms, finished with status: 'ok' 
D	    swat_load_bq	hlvygrg7fcvd	25/01/2022	22:28.9	Function execution started
I	    swat_load_bq	hlvygrg7fcvd	25/01/2022	22:28.9	File 'SWAT_outputs/TestRun4_monthly/output.hru' loaded into bucket
I	    swat_load_bq	hlvygrg7fcvd	25/01/2022	22:28.9	Loaded file is in SWAT_output folder and in target file list, loading to Big Query 
I	    swat_load_bq	hlvygrg7fcvd	25/01/2022	22:46.3	Loaded 509715 rows.
D	    swat_load_bq	hlvygrg7fcvd	25/01/2022	22:46.3	Function execution took 17350 ms, finished with status: 'ok'


# 3. View data in BigQuery

### Output tables

Each output file should end up in its own BigQuery table:

| Model output file | BigQuery table |
| --- | --- |
| output.rch | edf-aq-data.healthy_gulf.SWAT_output_rch |
| output.rsv | edf-aq-data.healthy_gulf.SWAT_output_rsv |
| output.sed | edf-aq-data.healthy_gulf.SWAT_output_sed |
| output.vel | edf-aq-data.healthy_gulf.SWAT_output_vel |

Results from each model run are simply appended to the correct table, along with metadata specific to that model run:


To check the latest model run in a table run the query below:

```sql
SELECT 
	model_info, 
	model_run_datetime, 
  model_time_interval,
	count(*) as ct, 
FROM `edf-aq-data.healthy_gulf.SWAT_output_sed` 
GROUP BY 1, 2, 3
ORDER BY model_run_datetime DESC
```

**Model time interval**

The MON field in these tables will hold either the month of the year (`%m`) or the day of the year (`%j`) depending on whether the `model_time_interval` is monthly or yearly.

Because BigQuery `PARSE_DATE` doesn’t support julian date, the date for yearly outputs should be parsed as below using the DATE_ADD function as a workaround:

```sql
SELECT DATE_ADD(PARSE_DATE('%Y', year), INTERVAL day - 1 DAY) as date
```

### Model vs. monitor tables

Three BigQuery views compare model results to monitoring data:

| View name | Model data | Monitoring data |
| --- | --- | --- |
| calibration_rch_gage_monthly | output.rch FLOW_OUT | usgs_gage_timeseries mean discharge (averaged to monthly) |
| calibration_rsv_lk_monthly | output.rsv FLOW_OUT | usgs_gage_timeseries_streammean discharge (averaged to monthly) |
| calibration_rsv_st_monthly | output.rsv VOLUME | usgs_gage_timeseries_lake storage volume (daily average then monthly average) |

In all these tables **sim** refers to the simulated data, i.e. model outputs, and **obs** to the observations, i.e. monitored data.

# 4. View performance stats and timeseries in Data Studio

A data studio dashboard displays model performance per site:

[**SWAT model calibration dashboard**](https://datastudio.google.com/reporting/2c478e67-0866-4984-ac2a-cf23a62bbc1f/page/7tCiC)

### Statistics

The view tables described above are further summarised to calculate the following statistics:

- Nash-Sutcliffe efficiency (NSE)
- Root mean square error (RMSE)
- RMSE-observations standard deviation ratio (RSR)
- Percent bias (PBIAS)

### Timeseries

Charts are displayed comparing model predictions and monitoring data over time. The drop-down filters at the top should be used to limit the model run and the site, otherwise data is summed across all.


# Making edits to the gcloud script

The code for the script is stored in gihub: https://github.com/edf-org/edf_custom_swat_support. Get hold of it with:

```r
git clone "https://github.com/edf-org/edf_custom_swat_support/02_gcloud_script"
```

After making any edits the script can be deployed back to gcloud with the following command (when the current directory is the one to be uploaded):

```r
gcloud functions deploy swat_load_bq --runtime python37 --trigger-resource healthy_gulf --trigger-event google.storage.object.finalize
```