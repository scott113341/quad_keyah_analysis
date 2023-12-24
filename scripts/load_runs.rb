#!/usr/bin/env ruby

require 'csv'
require 'open3'

STATES = %w[AZ CO NM UT]
LAT_LNG_REGEX = /<trkpt lat="([\-\d.]+)" lon="([\-\d.]+)">/

def run_pg_query(query)
  stdout_and_stderr, status = Open3.capture2e("psql", "-U", "postgres", "-d", "qka", "-c", query)
  puts(stdout_and_stderr)
  raise unless status == 0
end

def gpx_to_csv(state)
  CSV.open("/traces/#{state}.csv", "w") do |csv|
    File.open("/traces/#{state}.gpx").each do |line|
      if (match = line.match(LAT_LNG_REGEX))
        csv << [match[1], match[2]]
      end
    end
  end
end

STATES.each do |state|
  gpx_to_csv(state)

  run_pg_query("\\copy runs_import (lat, lng) FROM '/traces/#{state}.csv' DELIMITER ',' CSV;")

  run_pg_query <<-SQL
    INSERT INTO runs (state, geom)
    SELECT
      '#{state}' AS state,
      ST_MakeLine(ST_MakePoint(lng, lat) ORDER BY id) AS geom
    FROM runs_import;
  SQL

  run_pg_query("TRUNCATE TABLE runs_import;")
end

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
      ST_Length(ST_Intersection(r.geom, ST_Transform(s.geom, 4326))::geography) as dist_in_state
    from runs as r
    join states as s on ST_Intersects(r.geom, ST_Transform(s.geom, 4326))
  )

  select
    rd.state,
    rdies.state as part_in_state,
    rdies.dist_in_state,
    trunc((rdies.dist_in_state / rd.run_length * 100)::numeric, 2) || '%' as pct_in_state
  from run_distances rd
  inner join run_distances_in_each_state rdies on rd.state = rdies.race_state
  order by 1, 2;
SQL
