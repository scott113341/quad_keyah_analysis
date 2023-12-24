require 'open3'

def run_pg_query(query)
  stdout_and_stderr, status = Open3.capture2e("psql", "-U", "postgres", "-d", "qka", "-c", query)
  puts(stdout_and_stderr)
  raise unless status == 0
end
