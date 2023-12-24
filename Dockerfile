FROM postgis/postgis:16-3.4

# Initial setup & dependencies
RUN apt-get update && apt-get install -y \
    gpsbabel \
    netcat \
    postgis \
    procps \
    ruby \
    unzip \
    wget

# Download USA state shapefiles
WORKDIR /data
RUN wget -O states.zip https://www2.census.gov/geo/tiger/GENZ2018/shp/cb_2018_us_state_500k.zip
RUN unzip states.zip

# Init Postgres database
WORKDIR /scripts
COPY scripts/start_postgres.sh /scripts/start_postgres.sh
COPY scripts/stop_postgres.sh /scripts/stop_postgres.sh
RUN pg_createcluster 16 main
RUN echo "local all all trust" > /etc/postgresql/16/main/pg_hba.conf
RUN set -e \
    && ./start_postgres.sh \
    && echo "CREATE DATABASE qka;" | psql -U postgres \
    && echo "CREATE EXTENSION postgis;" | psql -U postgres -d qka \
    && echo "SELECT 1;" | psql -U postgres -d qka \
    && ./stop_postgres.sh

# Load state shape shapefiles
RUN set -e \
    && ./start_postgres.sh \
    && shp2pgsql -s 4269 -D /data/cb_2018_us_state_500k.shp states | psql -U postgres -d qka \
    && echo "SELECT COUNT(*) from states;" | psql -U postgres -d qka \
    && pg_dump -U postgres qka > /data/dump.sql \
    && ./stop_postgres.sh

# Create runs_import and runs tables to hold run data
RUN set -e \
    && ./start_postgres.sh \
    && echo "CREATE TABLE runs_import (id serial, lat float, lng float);" | psql -U postgres -d qka \
    && echo "CREATE TABLE runs (state TEXT, geom GEOMETRY(Linestring, 4326));" | psql -U postgres -d qka \
    && ./stop_postgres.sh

# Load run data
COPY traces /traces
COPY scripts/helpers.rb /scripts/helpers.rb
COPY scripts/load_runs.rb /scripts/load_runs.rb
RUN set -e \
    && ./start_postgres.sh \
    && ./load_runs.rb \
    && ./stop_postgres.sh

# Run analysis
COPY scripts/analyze.rb /scripts/analyze.rb
CMD set -e \
    && ./start_postgres.sh \
    && ./analyze.rb \
    && ./stop_postgres.sh
