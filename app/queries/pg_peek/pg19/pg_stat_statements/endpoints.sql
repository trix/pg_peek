-- Database cost per controller#action, from SQLcommenter tags.
--
-- Catalog queries are excluded throughout: Rails' schema introspection runs
-- once when a model loads and is tagged with whichever endpoint happened to
-- trigger it, so it both inflates that endpoint's cost and, sitting at calls=1
-- forever, destroys the min(calls) request-count estimate below.
WITH application_queries AS (
  SELECT
    COALESCE(
      substring(query from 'namespaced_controller=''([^'']+)'''),
      substring(query from 'controller=''([^'']+)''')
    ) AS controller,
    substring(query from 'action=''([^'']+)''') AS action,
    calls, total_exec_time, rows
  FROM pg_stat_statements
  WHERE userid = (SELECT usesysid FROM pg_user WHERE usename = current_user LIMIT 1)
    AND dbid = (SELECT oid FROM pg_database WHERE datname = current_database())
  AND query NOT LIKE '%/* pg_peek */%'
    AND query ~ 'controller=''[^'']+'''
    AND query ~ 'action=''[^'']+'''
    AND query !~* 'pg_catalog|information_schema|pg_index|pg_class|pg_attribute'
    AND query !~* '^\s*SHOW '
),
requests AS (
  -- Some query runs exactly once per request, so the smallest call count for an
  -- endpoint approximates how many times it was served.
  SELECT controller, action, min(calls) AS request_count
  FROM application_queries
  GROUP BY controller, action
)
SELECT
  q.controller || '#' || q.action AS endpoint,
  SUM(q.total_exec_time) AS total_exec_time_ms,
  SUM(q.calls) AS total_calls,
  COUNT(*) AS query_count,
  SUM(q.rows) AS total_rows,
  r.request_count,
  ROUND((MAX(q.calls)::numeric / NULLIF(r.request_count, 0)), 1) AS max_queries_per_request
FROM application_queries q
JOIN requests r ON r.controller = q.controller AND r.action = q.action
GROUP BY q.controller, q.action, r.request_count
ORDER BY total_exec_time_ms DESC
LIMIT {{limit}}
