--calculate bankfull cross-sectional area
with channel_dims as (
SELECT Subbasin, Width_m, Depth_m, Width_m-2*2*Depth_m bottom_width0_m
,if(Width_m-2*2*Depth_m <=0, Width_m*.5, Width_m-2*2*Depth_m) bottom_width_m
, 0.5*(Width_m+if(Width_m-2*2*Depth_m <=0, Width_m*.5, Width_m-2*2*Depth_m))*Depth_m bankfull_xsec_m2 
FROM `edf-aq-data.healthy_gulf.channel_dims`
)
--calculate bankfull flow and identify bankfull events
, bankfull_status as (
select Subbasin, DATE_ADD(DATE(b.year, 1, 1), INTERVAL CAST(c.MON as INT64) - 1 DAY) as datestamp
, flow_out / (bankfull_xsec_m2*velocity) as bankfullpct
, if(flow_out > bankfull_xsec_m2*velocity,1,0) isabovebankfull
, if(flow_out > bankfull_xsec_m2*velocity and lag(if(flow_out > bankfull_xsec_m2*velocity,1,0)) 
    over (partition by Subbasin order by DATE_ADD(DATE(b.year, 1, 1), INTERVAL CAST(c.MON as INT64) - 1 DAY)) = 0,1,0) isstartevent
from channel_dims 
join (select * from `edf-aq-data.healthy_gulf.SWAT_output_vel` where model_info = '20050101_20141231_res_c') b 
on channel_dims.Subbasin = cast(b.sub as int64)
join (select * from `edf-aq-data.healthy_gulf.SWAT_output_rch` where model_info = '20050101_20141231_res_c') c 
on cast(b.sub as int64) = c.rch and b.year=c.year and b.Day = c.MON and b.model_info=c.model_info
where b.model_info = '20050101_20141231_res_c'
and b.velocity != 0
)
--create unique bankfull event ids
-- , bankfull_events as (
select Subbasin, datestamp, bankfullpct, isabovebankfull, isstartevent, sum(isstartevent) over (partition by Subbasin order by datestamp) eventid
from bankfull_status
-- )
-- --calc stats on event durations
-- select Subbasin, avg(bankfull_duration_days) avg_event_duration_days, max(bankfull_duration_days) max_event_duration_days
-- from
-- (
-- --summarize event start date and duration
-- select Subbasin, eventid, min(datestamp) flood_start_date, count(eventid) bankfull_duration_days
-- from bankfull_events
-- where isabovebankfull = 1
-- group by Subbasin, eventid
-- --order by Subbasin, eventid
-- )
-- group by Subbasin
-- order by Subbasin
