# pg_peek UI architecture

Status: proposed. Supersedes the navigation implied by `FEATURES_SPEC.md`.

## The organizing idea

pg_peek has two axes, and only one of them is a reason for it to exist.

**The database axis** — tables, indexes, cache ratios, vacuum health. PgHero and
rails-pg-extras already cover this. Table stakes.

**The app axis** — which controller action, which job, which part of *your* code
costs database time. This comes from SQLcommenter tags written by
`config.active_record.query_log_tags`, and almost nothing does it well.

The UI should lead with the app axis and treat database internals as supporting
depth. Today it is arranged the other way round: the landing page is a list of
databases, which is the least informative page in the tool.

## Main page

Root currently renders `databases#index` — a router, not a view. With a single
database it is a pointless click. Root should answer **"is anything wrong, and
where is time going?"** on one screen, with the database list demoted to a
switcher.

```
db: [primary] queue analytics     overview queries endpoints jobs tables indexes activity

  postgres 18.6 · pg_stat_statements 1.12 · stats since 2h 14m ago · 1,284 statements

  where time goes                                attention
  posts#index       ███░░  38.2%   1.2s          ! cache hit 94.2% (below 99%)
  posts#show        ██░░░  21.0%   0.7s          ! post_views 18% dead, vacuum 3d ago
  PostAnalyticsJob  █░░░░  12.4%   0.4s          ! 4 unused indexes · 128 MB
  PostPublishJob    █░░░░   8.1%   0.3s          ! 2 queries running > 5s
  → endpoints  → jobs                            → tables → indexes → activity

  slowest queries                                activity
  00:00:01.204  SELECT … FROM posts WHERE …      12 conns · 3 active · 9 idle · max 100
  00:00:00.882  SELECT … FROM post_views …       longest: 4.2s  posts#index
  → queries                                      → activity
```

Two deliberate choices:

**The statistics window belongs in the header of every page.** "stats since 2h
14m ago" is the context that makes every number on the page interpretable, and
its absence has already caused an hour of confused debugging. A restart clears
`pg_stat_statements`; the UI should never let you forget that.

**"attention" is computed, not browsed.** It is what separates a tool that tells
you to do something from a data viewer.

## Sections

| section | question it answers | source |
|---|---|---|
| overview | anything wrong? where is the time going? | composed |
| queries | which statements are expensive? | `pg_stat_statements` |
| endpoints | which controller actions cost database time? | + `controller` / `action` tags |
| jobs | which jobs cost database time? | + `job` tag |
| tables | which tables are unhealthy? | `pg_stat_user_tables`, `pg_statio_user_tables` |
| indexes | what is unused, duplicated or missing? | `pg_stat_user_indexes` |
| activity | what is happening right now? | `pg_stat_activity`, `pg_locks` |
| settings | how is this server configured? | `pg_settings` |

## Endpoints

One row per `controller#action`:

```
endpoint            db time    share  calls  shapes  rows     q/req
posts#index         00:01.204  38.2%    412       8  41,200   ~19.4  ⚠
posts#show          00:00.701  21.0%    890       3   2,670    ~3.0
```

Detail view lists that endpoint's query shapes ranked by contribution, each
linking to the query.

### Queries per request, and the N+1 signal

`pg_stat_statements` has no request count, but one can be inferred. Within a
single endpoint, take `min(calls)` across its query shapes: some query runs
exactly once per request, so that minimum approximates the request count. Then
`calls / min_calls` is queries-per-request for each shape.

A shape at 10x while its siblings sit at 1x is an N+1, and the query is named.

### Validated against the dummy application

Measured with a controller issuing a deliberate ten-query N+1 on `#index` and a
single query on `#show`, against a freshly reset `pg_stat_statements`:

| endpoint | inferred requests | actual | q/req of the worst shape |
|---|---|---|---|
| `posts#index` | 6 | 6 | 10.0 — exactly the loop in the code |
| `posts#show` | 7 | 7 | 1.0 |

**The first attempt was wrong**, and instructively so. `posts#index` inferred 1
request rather than 6, because Rails' one-off schema introspection — `SHOW
max_identifier_length`, `pg_index`, `pg_class` and `pg_attribute` lookups — runs
once when a model first loads and is tagged with whichever endpoint happened to
trigger it. Those shapes sit at `calls = 1` forever and destroy a `min()`
denominator. `posts#show` appeared correct only because `#index` had already
paid that cost.

So the denominator must be taken over application queries only:

```sql
AND query !~* 'pg_catalog|information_schema|pg_index|pg_class|pg_attribute|^\s*SHOW'
```

With that exclusion both endpoints infer their true request count and the N+1
factor lands on the exact number in the source.

### Remaining caveats

- it still breaks when every query in an action is conditional, so no shape runs
  exactly once per request
- values are averages across the whole statistics window, not per-request truth
- an action whose behaviour changed mid-window blends both behaviours

Show it prefixed with `~` and explain on hover rather than presenting it as
measurement.

### A limit of the approach, found the hard way

`pg_stat_statements` keys on `queryid`, which is computed from the parse tree
and **ignores comments**. Two executions of the same normalised shape from
different endpoints share one row, and that row's stored text -- including its
SQLcommenter tags -- is whichever ran *first* since the last reset.

So a query shape shared across endpoints is attributed to only one of them.
A `find_by(id:)` issued from three actions counts entirely against the first
to run it. Shapes unique to an action attribute correctly, which in practice
is most of them, but the figures are a lower bound per endpoint, not a
partition of total time.

This surfaced as an order-dependent test failure: an untagged model-level
query claimed the row an integration test expected to see tagged. It is also
the strongest concrete argument for `pg_stat_monitor`, which keeps comments as
a dimension -- and why the README explains that choice rather than dismissing
it.

### pg_peek's own queries

Every statement the engine issues carries a trailing `/* pg_peek */` comment,
added in `QueryLoader`, and the statistics queries exclude anything containing
it. It has to be trailing: `pg_stat_statements` stores a statement from its
first token, so a leading comment is dropped -- while trailing text survives,
which is also why Rails' own tags do.

### Tag naming

The controller tag is `controller` in some applications and
`namespaced_controller` in others — the dummy app uses the first, a real
application we tested against uses the second. Read both with `COALESCE` and
show which one was found.

## Jobs

Same machinery, different questions. For endpoints, per-request latency matters.
For jobs, **total cost and rows touched** matter: nobody minds a nightly job
taking 40ms per query, they mind it burning 30% of the database.

So jobs rank on total time and rows, and surface **rows per call** where
endpoints surface queries per request.

Jobs also cross databases — the dummy's `PostEngagementJob` queries primary and
analytics. The job detail page is the natural home for cross-database
attribution, and the only place in the tool where it is worth the complexity.

**Scope boundary:** this is not a job queue dashboard. Queue depth, retries and
failures belong to GoodJob and Solid Queue. pg_peek links out; it does not
compete. Its lane is the database cost of jobs.

## URLs

`CLAUDE.md` states that everything is database-prefixed and that GET links
should be shareable. The current top-level `/jobs` breaks the first rule.

```
/databases/:db                    overview
/databases/:db/queries            ?sort= &controller= &job= &table=
/databases/:db/queries/:queryid   one query shape
/databases/:db/endpoints[/:name]
/databases/:db/jobs[/:name]
/databases/:db/tables[/:name]
/databases/:db/indexes
/databases/:db/activity
/databases/:db/settings
```

Filters as query parameters keeps links shareable. `queryid` makes an individual
statement linkable; it is stable within a PostgreSQL major version, so treat a
miss as "this query is no longer tracked" rather than an error.

### Debt this absorbs

- `by_controller_action`, `by_job`, `by_table_name` are routed to empty actions
  with no templates and currently raise. They become `endpoints`, `jobs` and a
  `queries?table=` filter.
- The dead `@table_filter` branch in `outliers.html.erb`, which references a
  route helper that does not exist, becomes the real table filter.
- The reset button hardcodes `"primary"` and resets the wrong database when
  viewing a secondary.

## Deliberately out of scope

**Historical trends.** `pg_stat_statements` is cumulative since reset. Trends
require snapshot storage, which means migrations in the host application — a
significant commitment for a tool that currently installs read-only. Revisit
later as opt-in.

**Killing queries and running EXPLAIN.** Both useful, both risky: `EXPLAIN` on a
normalized statement requires inventing parameter values. Later, if at all.

## Delivery order

1. **Report layer.** Reports expose columns and rows; one generic renderer draws
   any of them. No new SQL. Empty states handled once rather than per page.
2. **Endpoints.** Reuses the jobs machinery. The N+1 heuristic lands here.
3. **Overview.** Mostly composition of 1 and 2 plus a few cheap vitals queries.
4. **Indexes.** Self-contained SQL, the highest value per line in this document.
5. **Activity.** Different data source and refresh semantics.
6. **CLI.** Nearly free once reports exist: `pg_peek endpoints --sort total_time`.

Steps 1 and 2 are what make the rest cheap. Step 4 is worth jumping the queue
for a quick win — unused indexes is one query that routinely finds hundreds of
megabytes.
