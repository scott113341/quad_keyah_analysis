#!/usr/bin/env ruby

require 'csv'
require_relative './helpers.rb'

STATES = %w[AZ CO NM UT]
LAT_LNG_REGEX = /<trkpt lat="([\-\d.]+)" lon="([\-\d.]+)">/

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
