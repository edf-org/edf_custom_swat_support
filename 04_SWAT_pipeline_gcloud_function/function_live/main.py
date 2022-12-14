import pandas as pd 
import numpy as np
import config as cfg
import swat_format
import os
import gc
import re
import tracemalloc
import shutil
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

    storage_client = storage.Client()
    
    tmp_path = '/tmp/' + file_path.split('/')[-1]
    
    bucket = storage_client.get_bucket(bucket_nm)
    blob = bucket.blob(file_path)
    blob.download_to_filename(tmp_path)
    
    return tmp_path


def clear_folder(path):
    folder = path
    for filename in os.listdir(folder):
        file_path = os.path.join(folder, filename)
        try:
            if os.path.isfile(file_path) or os.path.islink(file_path):
                os.unlink(file_path)
            elif os.path.isdir(file_path):
                shutil.rmtree(file_path)
        except Exception as e:
            print('Failed to delete %s. Reason: %s' % (file_path, e))



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


def read_cio(fpath):
    """Function to read the file.cio which model run information

    Args:
        fpath: the path to the file in temp
    Returns:
        Dict; storing the start and end dates of the model run period
        with two years added to the start, and 2 years subtracted from the
        duration to account for the two year model wind up period.
    """
    
    cio = pd.read_fwf(fpath, skiprows = 7, header = None, nrows = 4)
    
    n_years = int(cio.loc[0, 0].split(' ')[0]) - 2
    year_start = int(cio.loc[1, 0].split(' ')[0]) + 2

    dict_cio = {'start' : '01/01/' + str(year_start),
                'end' : '31/12/' + str(year_start + n_years - 1)}
    
    return dict_cio




def read_SWAT(fpath):
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
    file_headers = pd.read_csv(write_to_tmp("healthy_gulf", "SWAT_outputs/file_metadata_headers.csv"))

    # pull file type from the filename
    ftype = fpath.split('.')[1]

    # extract the headers list and line skip info from the metadata files
    try:
        header_values = file_headers[ftype][~file_headers[ftype].isnull()].values
        skip_value = cfg.file_skips[ftype]

    except KeyError:
        print("File type .{} not found in 'file_metadata_....csv' file".format(ftype))
        raise
    
    # read file
    df = pd.read_fwf(fpath, skiprows = skip_value, header = None, infer_nrows=100000) 
    # cut off useless column for rsv, rch, sed and sub files
    if (ftype in cfg.file_cut):
        df = df.iloc[:, 1:]
         
    # add in column headers
    try:
        df.columns = header_values

    except ValueError:
        print("n columns in output file {} does not match n columns in 'file_metadata_headers.csv'".format(fpath))
        raise
        
    return df


def read_SWAT_sub(fpath, ftype, model_desc, model_period, cio_dict):

    chunk_s = 1000000
    load_time = datetime.now().strftime("%Y/%m/%d %H:%M:%S")

    # read first n rows of file (up to header)
    with open(fpath) as file:
        head = [next(file) for x in range(cfg.file_skips[ftype])]

    # calc the no. of variable columns beyond the first fixed ones
    width_total = len(head[-1])
    width_fixed = sum(cfg.fixed_col_widths[ftype]) + 1
    n_var_cols = int((width_total - width_fixed) / cfg.var_col_width[ftype])

    h_col_widths = cfg.fixed_col_widths[ftype] + ([cfg.var_col_width[ftype]] * n_var_cols)

    # create list of column widths
    if n_var_cols > 18:
        col_widths = cfg.fixed_col_widths[ftype] + ([cfg.var_col_width[ftype]] * 18) + [11] + ([cfg.var_col_width[ftype]] * (n_var_cols - 19))

    else:                                                                            
        col_widths = cfg.fixed_col_widths[ftype] + ([cfg.var_col_width[ftype]] * n_var_cols)

    # dictionary of dtypes
    dtypes = dict(zip(range(cfg.n_fixed_cols[ftype] + n_var_cols),
                      cfg.fixed_col_dtypes[ftype] + ([np.float32] * n_var_cols) ))

    df_headers = pd.read_fwf(fpath, 
                     skiprows = cfg.file_skips[ftype] - 1, 
                     nrows = 0, 
                     widths = h_col_widths)

    df_headers.columns = [re.sub('[^A-Za-z0-9_ ]', '', c).replace(" ", "_") for c in df_headers.columns]

    reader = pd.read_fwf(fpath, 
                         skiprows = cfg.file_skips[ftype]-1,
                         widths = [col_widths[0] + 1] + col_widths[1:],
                         dtype = dtypes, 
                         chunksize = chunk_s)

    for i, chunk in enumerate(reader):

        chunk.columns = df_headers.columns
        chunk = chunk.iloc[:, 1:]

        # format chunk to add in date field
        df = swat_format.format_sub(chunk, model_period, cio_dict, chunk_s, i, len(chunk))

        # add model info
        df['model_run_datetime'] = load_time
        df['model_info'] = model_desc
        df['model_time_interval'] = model_period

        push_to_bq(df, "healthy_gulf", "SWAT_output_" + ftype) 

        # MEMORY USE OUT ===========>
        current, peak = tracemalloc.get_traced_memory()
        print(f"Chunk {i} pushed, Current memory usage is {current / 10**6}MB; Peak was {peak / 10**6}MB")                  

    print("SUB done!")



def read_SWAT_hru(fpath, ftype, model_desc, model_period, cio_dict):

    chunk_s = 1500000
    load_time = datetime.now().strftime("%Y/%m/%d %H:%M:%S")

    with open(fpath) as fp:
        cnt = 1
        while cnt <= cfg.file_skips[ftype]:
            head = fp.readline()
            cnt += 1
            
    # calc the no. of variable columns (10 char wide) past the first fixed 7
    width_total = len(head)
    width_fixed = sum(cfg.fixed_col_widths[ftype]) + 1
    n_var_cols = int((width_total - width_fixed) / cfg.var_col_width[ftype])

    # create list of column widths
    col_widths = cfg.fixed_col_widths[ftype] + ([cfg.var_col_width[ftype]] * n_var_cols)

    # dictionary of dtypes
    dtypes = dict(zip(range(cfg.n_fixed_cols[ftype] + n_var_cols),
                      cfg.fixed_col_dtypes[ftype] + ([np.float32] * n_var_cols) ))

    # # MEMORY USE OUT ===========>
    # current, peak = tracemalloc.get_traced_memory()
    # print(f"Inital vars done, Current memory usage is {current / 10**6}MB; Peak was {peak / 10**6}MB")

    # read file
    reader = pd.read_fwf(fpath, 
                         skiprows = cfg.file_skips[ftype]-1,
                         widths = col_widths,
                         dtype = dtypes, 
                         chunksize = chunk_s)

    for i, chunk in enumerate(reader):

        chunk.columns = [c.replace('/', '_') for c in chunk.columns]

        # format chunk to add in date field
        df = swat_format.format_hru(chunk, model_period, cio_dict, chunk_s, i, len(chunk))

        # add model info
        df['model_run_datetime'] = load_time
        df['model_info'] = model_desc
        df['model_time_interval'] = model_period

        push_to_bq(df, "healthy_gulf", "SWAT_output_" + ftype)

        # MEMORY USE OUT ===========>
        current, peak = tracemalloc.get_traced_memory()
        print(f"Chunk {i} pushed, Current memory usage is {current / 10**6}MB; Peak was {peak / 10**6}MB")

    print("HRU done!")



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

    # tracemalloc.start()

    print("File '{}' loaded into bucket".format(event['name']))
    clear_folder('/tmp/')

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

            # try reading in file.cio
            try:
                path_cio = os.path.split(event['name'])[0] + '/file.cio'
                temp_cio = write_to_tmp(event['bucket'], path_cio)
                cio_dict = read_cio(temp_cio)
                
            except:
                print('file.cio is missing from directory. Please add in then re-upload output files.')
                raise

            # write file to temp location and read
            tmp_path = write_to_tmp(event['bucket'], event['name'])

            # current, peak = tracemalloc.get_traced_memory()
            # print(f"Written output to tmp, memory usage is {current / 10**6}MB; Peak was {peak / 10**6}MB")

            # specific reads for hru and sub, all others standard
            if (ftype == 'hru'):
                print('running hru read')
                read_SWAT_hru(tmp_path, ftype, model_desc, model_period, cio_dict)
            
            elif (ftype == 'sub'):
                print('running sub read')
                read_SWAT_sub(tmp_path, ftype, model_desc, model_period, cio_dict)
            
            else:
                print('running standard read')
                df = read_SWAT(tmp_path)

            # current, peak = tracemalloc.get_traced_memory()
            # print(f"Processed output, memory usage is {current / 10**6}MB; Peak was {peak / 10**6}MB")
            
            if (ftype not in ['hru', 'sub']):

                # pull appropriate formatting function from module
                formatter = getattr(swat_format, 'format_' + ftype)
                df = formatter(df, model_period, cio_dict)

                # current, peak = tracemalloc.get_traced_memory()
                # print(f"Formatted output, memory usage is {current / 10**6}MB; Peak was {peak / 10**6}MB")
            
                # METADATA
                # add in date field
                df['model_run_datetime'] = datetime.now().strftime("%Y/%m/%d %H:%M:%S")
                df['model_info'] = model_desc
                df['model_time_interval'] = model_period

                # BQ LOAD
                push_to_bq(df, "healthy_gulf", "SWAT_output_" + ftype)

                # current, peak = tracemalloc.get_traced_memory()
                # print(f"Pushed output to BQ, memory usage is {current / 10**6}MB; Peak was {peak / 10**6}MB")

            # clear out tmp directory
            clear_folder('/tmp/')
            # del df
            gc.collect()

            # current, peak = tracemalloc.get_traced_memory()
            # print(f"Cleared down tmp and df, memory usage is {current / 10**6}MB; Peak was {peak / 10**6}MB")


        else:
            print("Model time interval not found in output folder name, add and re-upload")
            return
        
    else:
        print("Loaded file type is not in SWAT_output folder or target file list, ignoring")
        return

    # tracemalloc.stop()
 