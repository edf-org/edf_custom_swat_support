SELECT 
	model_info,
	-- take source subbasin from model_info field
	CAST(SUBSTR(model_info, LENGTH(model_info) - 2, LENGTH(model_info)) AS INT64) as source_sub,
	RCH as receptor_sub,
	avg(SOLPST_IN) as avg_solpst_in,
	avg(SORPST_IN) as avg_sorpst_in,
	count(*) as count
    
FROM `edf-aq-data.healthy_gulf.SWAT_output_rch` 

-- limit to daily chemtest runs
WHERE 
	SUBSTR(model_info, 1, 8) = "chemtest"
	AND model_time_interval = "daily" 

GROUP BY 1, 2, 3

-- select only receptor subbasins by filtering to those which have PST data
HAVING max(SOLPST_IN) > 0 or max(SORPST_IN) > 0
ORDER BY model_info, source_sub, receptor_sub