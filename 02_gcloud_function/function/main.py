import pandas as pd 
import config as cfg
import swat_format
from datetime import datetime
from google.cloud import storage
from google.cloud import bigquery


def write_to_tmp(bucket_nm, file_path):
    """Function to write a file in a bucket to temp folder for function to work with

    Args:
        bucket_nm: The name of the bucket the file is stored in 
        file_path: The location of the file
    Returns:
        String: the location of the file written to temp storage
        e.g. 'tmp/file_name'
    """
    
    # takes a bucket name and file path, writes the file to tmp, and returns the tmp file path
    
    storage_client = storage.Client()
    
    tmp_path = '/tmp/' + file_path.split('/')[-1]
    
    bucket = storage_client.get_bucket(bucket_nm)
    blob = bucket.blob(file_path)
    blob.download_to_filename(tmp_path)
    
    return tmp_path



def push_to_bq(df, dataset_nm, table_nm):
    """Function to push a dataframe to a BigQuery table

    Args:
        df: dataframe to be loaded into BigQuery
        dataset_nm: name of the target data set in in BigQuery
        table_nm: name of the target table in BigQuery
    Returns:
        None; the number of rows uploaded is printed
    """
    
    bq_client = bigquery.Client()
    
    job_config = bigquery.LoadJobConfig()
    job_config.write_disposition = 'WRITE_APPEND' 

    table_ref = bq_client.dataset(dataset_nm).table(table_nm)
    job = bq_client.load_table_from_dataframe(df, table_ref, job_config=job_config) 
    
    try:
        job.result()  # Waits for table load to complete.
    except BadRequest as err:
        print(job.errors)
        raise
        
    print('Loaded {} rows.'.format(job.output_rows))




def read_SWAT(fpath, model_period):
    """Function to carry out basic read-in of a SWAT model output file

    Args:
        fpath: the file location in gcloud temp storage
        model_period: either 'monthly' or 'daily' depending on the model run
    Returns:
        DataFrame: A basically formatted version of the output file
        with the file headers supplied in the metadata but no further 
        file-specific formatting
    """

    # read in meta data to help read output files
    file_headers = pd.read_csv(write_to_tmp("healthy_gulf", "SWAT_outputs/file_metadata_headers_" + model_period + ".csv"))
    file_skips = pd.read_csv(write_to_tmp("healthy_gulf", "SWAT_outputs/file_metadata_skips.csv"))
    
    # pull file type from the filename
    ftype = fpath.split('.')[1]

    # extract the headers list and line skip info from the metadata files
    try:
        header_values = file_headers[ftype][~file_headers[ftype].isnull()].values
        skip_value = file_skips[ftype].values[0]

    except KeyError:
        print("File type .{} not found in 'file_metadata_....csv' file".format(ftype))
        raise
    
    # read file
    df = pd.read_fwf(fpath, skiprows = skip_value, header = None, infer_nrows=100000) #, nrows=10000

    # cut off useless column for rsv, rch and sed files
    if (ftype in ['rsv', 'rch', 'sed']):
        df = df.iloc[:, 1:]
         
    # add in column headers
    try:
        df.columns = header_values

    except ValueError:
        print("n columns in output file {} does not match n columns in 'file_metadata_headers.csv'".format(fpath))
        raise
        
    return df


def fix_hru(tmp_path):
    """Function to fix the hru output file and write to an updated temp location

    Args:
        tmp_path: the file path in temp 
    Returns:
        String: the file path of the new fixed file
    """

    # insert a space into the 34th position of each line
    with open(tmp_path) as in_f, open(tmp_path.replace('.', '_fixed.'), 'w') as out_f:
        for line in in_f:
            if len(line) > 34:
                out_line = line[0:34] + ' ' + line[34:-1] + '\n'
                out_f.write(out_line)
            else:
                out_f.write(line)

    return tmp_path.replace('.', '_fixed.')



def bq_load(event, context):
    """Background Cloud Function to be triggered by Cloud Storage.
       This generic function logs relevant data when a file is changed.

    Args:
        event (dict):  The dictionary with data specific to this type of event.
                       The `data` field contains a description of the event in
                       the Cloud Storage `object` format described here:
                       https://cloud.google.com/storage/docs/json_api/v1/objects#resource
        context (google.cloud.functions.Context): Metadata of triggering event.
    Returns:
        None; the output is written to Stackdriver Logging
    """

    print("File '{}' loaded into bucket".format(event['name']))

    # extract file type from name
    ftype = event['name'].split('.')[1]
    path_arr = event['name'].split('/')
    folder = path_arr[0]
    
    # check file is in correct folder, matches target file types, and also is in a sub-folder of 'SWAT_outputs' 
    if (folder == 'SWAT_outputs') and (ftype in cfg.target_files) and (len(path_arr) > 2):
        
        print("Loaded file is in SWAT_output folder and in target file list, loading to Big Query")

        # try extracting model info from file path
        try:
            model_info = path_arr[1].split('_') # create array of '_' separated text parts in folder name
            model_desc = '_'.join(model_info[0:-1]) # create string from all parts but last of folder name
            model_period = model_info[-1] # take period from last part of folder name

        except:
            print("Could not retrieve model info from folder name. Create a new folder in 'SWAT_outputs' with 'ModelInfo_TimeInterval' format")
            raise

        if model_period in ['monthly', 'daily']:

            # write file to temp location and read
            tmp_path = write_to_tmp(event['bucket'], event['name'])

            # if hru output create fixed file in temp
            if (ftype == 'hru'):
                tmp_path = fix_hru(tmp_path)
                print('written fixed hru file to temp')

            df = read_SWAT(tmp_path, model_period)
            
            # pull appropriate formatting function from module
            formatter = getattr(swat_format, 'format_' + ftype)

            df = formatter(df, model_period)
        
            # METADATA
            # add in date field
            df['model_run_datetime'] = datetime.now().strftime("%Y/%m/%d %H:%M:%S")
            df['model_info'] = model_desc
            df['model_time_interval'] = model_period

            # BQ LOAD
            push_to_bq(df, "healthy_gulf", "SWAT_output_" + ftype)
        
        else:
            print("Model time interval not found in output folder name, add and re-upload")
            return
        
    else:
        print("Loaded file type is not in SWAT_output folder or target file list, ignoring")
        return
 