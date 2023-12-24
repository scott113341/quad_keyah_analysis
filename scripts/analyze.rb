#!/usr/bin/env ruby

require_relative './helpers.rb'

run_pg_query <<-SQL
  with
  
  run_distances as (
    select
      state,
      ST_Length(geom::geography) as run_length
    from runs
  ),
  
  run_distances_in_each_state as (
    select
      r.state as race_state,
      s.stusps as state,
      ST_Length(ST_Intersection(r.geom, ST_Transform(s.geom, 4326))::geography) as dist_in_state_meters
    from runs as r
    join states as s on ST_Intersects(r.geom, ST_Transform(s.geom, 4326))
  )

  select
    rd.state as race,
    rdies.state as state_portion,
    rdies.dist_in_state_meters,
    trunc((rdies.dist_in_state_meters / rd.run_length * 100)::numeric, 2) || '%' as pct_in_state
  from run_distances rd
  inner join run_distances_in_each_state rdies on rd.state = rdies.race_state
  order by array_position(array['AZ', 'UT', 'CO', 'NM'], rd.state), 3 desc;
SQL
