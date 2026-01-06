pg_peek's superpower: Access to pg_stat_statements - the source of truth for all query performance data.

solid_queue's data: Jobs with class names, timing, arguments - all in PostgreSQL.

The intersection nobody else can do: Correlate job execution with actual database cost.

---
Killer Feature: Job → Query Cost Attribution

pg_peek already parses SQLcommenter (/*key=value*/). Rails 7+ has ActiveRecord::QueryLogs which can tag queries with context. If jobs tag their queries:

# What pg_stat_statements sees:
SELECT * FROM users WHERE id = $1 /*job_class=ImportUsersJob,job_id=abc123*/

pg_peek could show:

| Job Class      | Total DB Time | % of Load | Queries/Job | Slowest Query           |
|----------------|---------------|-----------|-------------|-------------------------|
| ImportUsersJob | 847s          | 34%       | 1,247       | SELECT * FROM orders... |
| NotifyJob      | 312s          | 12%       | 3           | UPDATE users SET...     |

This is APM-level insight that no job dashboard provides because they don't have pg_stat_statements access. And no database tool provides it because they don't understand jobs.

---
Secondary Features (unique to the PostgreSQL angle):

1. solid_queue table health - bloat, dead tuples, vacuum stats, index usage on the queue tables themselves. "Your jobs table has 40% bloat"
2. Worker ↔ pg_stat_activity correlation - cross-reference solid_queue_processes (pid, hostname) with live pg_stat_activity to show what queries workers are running right now
3. Failure ↔ database error correlation - parse solid_queue_failed_executions.error and correlate with database issues (deadlocks, lock timeouts, statement timeouts)
4. Job latency vs query time - "This job took 30s but only 2s was database" vs "28s of 30s was waiting on queries"

---
The query attribution feature would be genuinely differentiated. Companies pay significant money for APM tools that provide this insight, and pg_peek could do it natively by leveraging what it already has.


What's the #1 pain point with background jobs?

 "Why is this job stuck/slow?"

 Job dashboards show job state but not why. Database tools show queries but not which job.

 ---
 Killer Feature #2: Live Job Database Debugger

 Cross-reference solid_queue_processes (worker PIDs) + solid_queue_claimed_executions (current jobs) + pg_stat_activity (live queries) + pg_locks:

 | Worker   | Job            | Running | Current Query                  | State                        |
 |----------|----------------|---------|--------------------------------|------------------------------|
 | worker-1 | ImportUsersJob | 47s     | UPDATE users SET...            | ⏳ waiting: RowExclusiveLock |
 | worker-2 | NotifyJob      | 2s      | SELECT * FROM notif...         | active                       |
 | worker-3 | ReportJob      | 3m 22s  | SELECT COUNT(*) FROM orders... | active (seq scan)            |

 Click the blocked worker → see the full lock chain:

 ImportUsersJob (worker-1)
   └─ waiting on RowExclusiveLock on users (row 4821)
       └─ held by: PID 9823 (web request: POST /admin/users/4821)
           └─ transaction open for 12s

 This is impossible without both solid_queue tables AND pg_stat_activity/pg_locks.

 ---
 Why this is killer:

 1. Instant "why is my job stuck?" answers - no more guessing
 2. Shows job→query→lock→blocker chains - full causality
 3. Real-time/live - watch jobs as they execute
 4. Cross-system visibility - see when web requests block jobs (or vice versa)
 5. Zero instrumentation - just reads existing PostgreSQL system tables

 ---
 Bonus insight from this view:

 - Transaction duration per job - "ImportUsersJob holds transactions open for avg 45s, blocking autovacuum"
 - Connection pool pressure - "Workers hold 35/50 connections, 28 are idle in transaction"
 - Lock hotspots - "The users table is a lock contention hotspot from jobs"

 ---
 So the two killer features:

 1. Job → Query Cost Attribution (via SQLcommenter) - "Which jobs cost the most database time?"
 2. Live Job Database Debugger (via pg_stat_activity + pg_locks) - "Why is this job stuck right now?"

 Both are genuinely unique to pg_peek's position at the intersection of job state and database internals.
