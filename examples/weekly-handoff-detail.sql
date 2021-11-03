-- Compute a weekly report of high-urgency incidents

-- Results include one row per incident, with information about the incident
-- as well as statistics on how many person-hours were interrupted by the
-- incident, how many off those hours were off-hours, how many people were
-- interrupted by the incident, and which people.

with notifications as (
select
  log_entries.id,
  date_trunc('hour', log_entries.created_at) as interrupted_hour,
  case
    when (
      -- On-hours = Monday through Friday, 9am through 6pm
      extract(dow from log_entries.created_at at time zone 'America/Los_Angeles') >= 1 and
      extract(dow from log_entries.created_at at time zone 'America/Los_Angeles') <= 5 and
      extract(hour from log_entries.created_at at time zone 'America/Los_Angeles') >= 9 and
      extract(hour from log_entries.created_at at time zone 'America/Los_Angeles') <= 17
    ) then false
    else true
  end as off_hour,
  log_entries.incident_id,
  split_part(users.email, '@', 1) as username
from
  log_entries,
  users
where
  log_entries.type = 'notify_log_entry'
  and log_entries.created_at >= (timestamp '2021-10-25 11:00-07')
  and log_entries.created_at < (timestamp '2021-10-25 11:00-07' + interval '1 week')
  and log_entries.user_id = users.id
),

incident_interruptions as (
select
  incident_id,
  count(distinct username || interrupted_hour) as interrupted_hours,
  count(distinct username || interrupted_hour) filter (where off_hour) as interrupted_off_hours,
  count(distinct username) as interrupted_people_count,
  string_agg(distinct username, ', ') as interrupted_people,
  min(interrupted_hour) as first_interrupted_hour,
  max(interrupted_hour) as last_interrupted_hour
from
  notifications
group by
  incident_id
)

select
  incidents.html_url as incident_url,
  incidents.trigger_summary_subject as incident_subject,
  services.name as service_name,
  incident_interruptions.interrupted_hours,
  nullif(incident_interruptions.interrupted_off_hours, 0) as interrupted_off_hours,
  incident_interruptions.interrupted_people_count,
  incident_interruptions.interrupted_people,
  incident_interruptions.first_interrupted_hour
from
  incidents,
  incident_interruptions,
  services
where
  incidents.urgency = 'high'
  and incidents.id =incident_interruptions.incident_id
  and incidents.service_id = services.id
order by
  incidents.created_at desc
;
