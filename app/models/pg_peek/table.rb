class PgPeek::Table
  attr_reader :database, :name

  STATS_QUERY = <<~SQL.freeze
    SELECT
      t.relname AS table_name,
      t.seq_scan,
      t.seq_tup_read,
      t.idx_scan,
      t.idx_tup_fetch,
      t.n_tup_ins,
      t.n_tup_upd,
      t.n_tup_del,
      t.n_live_tup,
      t.n_dead_tup,
      t.last_vacuum,
      t.last_autovacuum,
      t.last_analyze,
      t.last_autoanalyze,
      t.vacuum_count,
      t.autovacuum_count,
      t.analyze_count,
      t.autoanalyze_count,
      s.heap_blks_read,
      s.heap_blks_hit,
      s.idx_blks_read,
      s.idx_blks_hit,
      s.toast_blks_read,
      s.toast_blks_hit,
      s.tidx_blks_read,
      s.tidx_blks_hit,
      c.reltuples AS row_estimate
    FROM pg_stat_user_tables t
    LEFT JOIN pg_statio_user_tables s ON t.relid = s.relid
    LEFT JOIN pg_class c ON t.relid = c.oid
    WHERE t.relname = $1
  SQL

  STATS_RESET_QUERY = "SELECT stats_reset FROM pg_stat_bgwriter".freeze

  def self.inline_stats_for(database, table_names)
    return {} if table_names.empty?

    placeholders = table_names.map.with_index { |_, i| "$#{i + 1}" }.join(", ")
    query = <<~SQL
      SELECT
        t.relname AS table_name,
        s.heap_blks_read,
        s.heap_blks_hit,
        s.idx_blks_read,
        s.idx_blks_hit
      FROM pg_stat_user_tables t
      LEFT JOIN pg_statio_user_tables s ON t.relid = s.relid
      WHERE t.relname IN (#{placeholders})
    SQL

    result = database.connection.exec_query(query, "PgPeek::Table InlineStats", table_names)
    result.rows.each_with_object({}) do |row, hash|
      table_name = row[0]
      heap_blks_read = row[1].to_i
      heap_blks_hit = row[2].to_i
      idx_blks_read = row[3].to_i
      idx_blks_hit = row[4].to_i

      hash[table_name] = {
        heap_hit_ratio: cache_hit_ratio(heap_blks_hit, heap_blks_read),
        index_hit_ratio: cache_hit_ratio(idx_blks_hit, idx_blks_read)
      }
    end
  end

  def self.cache_hit_ratio(hits, reads)
    total = hits + reads
    return nil if total.zero?
    (hits.to_f / total * 100).round(1)
  end

  def self.excluded?(table_name)
    PgPeek.config.excluded_tables.any? do |pattern|
      case pattern
      when Regexp
        pattern.match?(table_name)
      when String
        pattern == table_name
      else
        false
      end
    end
  end

  def initialize(database, name)
    @database = database
    @name = name
  end

  def stats
    @stats ||= fetch_stats
  end

  def stats_reset_at
    @stats_reset_at ||= begin
      result = database.connection.execute(STATS_RESET_QUERY)
      result.first&.dig("stats_reset")
    end
  end

  def seconds_since_reset
    return nil unless stats_reset_at
    Time.current - stats_reset_at
  end

  # Cache metrics
  def heap_cache_hit_ratio
    self.class.cache_hit_ratio(heap_blks_hit, heap_blks_read)
  end

  def index_cache_hit_ratio
    self.class.cache_hit_ratio(idx_blks_hit, idx_blks_read)
  end

  def toast_cache_hit_ratio
    self.class.cache_hit_ratio(toast_blks_hit, toast_blks_read)
  end

  def toast_index_cache_hit_ratio
    self.class.cache_hit_ratio(tidx_blks_hit, tidx_blks_read)
  end

  # Row stats
  def seq_scan
    stats["seq_scan"].to_i
  end

  def idx_scan
    stats["idx_scan"].to_i
  end

  def total_scans
    seq_scan + idx_scan
  end

  def seq_scan_percentage
    return nil if total_scans.zero?
    (seq_scan.to_f / total_scans * 100).round(1)
  end

  def idx_scan_percentage
    return nil if total_scans.zero?
    (idx_scan.to_f / total_scans * 100).round(1)
  end

  def index_usage_percentage
    idx_scan_percentage
  end

  def seq_tup_read
    stats["seq_tup_read"].to_i
  end

  def idx_tup_fetch
    stats["idx_tup_fetch"].to_i
  end

  def rows_fetched
    seq_tup_read + idx_tup_fetch
  end

  def rows_inserted
    stats["n_tup_ins"].to_i
  end

  def rows_updated
    stats["n_tup_upd"].to_i
  end

  def rows_deleted
    stats["n_tup_del"].to_i
  end

  def live_tuples
    stats["n_live_tup"].to_i
  end

  def dead_tuples
    stats["n_dead_tup"].to_i
  end

  def dead_tuple_ratio
    total = live_tuples + dead_tuples
    return nil if total.zero?
    (dead_tuples.to_f / total * 100).round(1)
  end

  def dead_tuple_warning?
    ratio = dead_tuple_ratio
    return false if ratio.nil?
    ratio >= PgPeek.config.dead_tuple_warning_threshold
  end

  def row_estimate
    estimate = stats["row_estimate"]
    estimate.nil? ? 0 : estimate.to_i
  end

  # Vacuum/maintenance stats
  def last_vacuum
    stats["last_vacuum"]
  end

  def last_autovacuum
    stats["last_autovacuum"]
  end

  def last_analyze
    stats["last_analyze"]
  end

  def last_autoanalyze
    stats["last_autoanalyze"]
  end

  def vacuum_count
    stats["vacuum_count"].to_i
  end

  def autovacuum_count
    stats["autovacuum_count"].to_i
  end

  def analyze_count
    stats["analyze_count"].to_i
  end

  def autoanalyze_count
    stats["autoanalyze_count"].to_i
  end

  # Cache block stats (raw)
  def heap_blks_read
    stats["heap_blks_read"].to_i
  end

  def heap_blks_hit
    stats["heap_blks_hit"].to_i
  end

  def idx_blks_read
    stats["idx_blks_read"].to_i
  end

  def idx_blks_hit
    stats["idx_blks_hit"].to_i
  end

  def toast_blks_read
    stats["toast_blks_read"].to_i
  end

  def toast_blks_hit
    stats["toast_blks_hit"].to_i
  end

  def tidx_blks_read
    stats["tidx_blks_read"].to_i
  end

  def tidx_blks_hit
    stats["tidx_blks_hit"].to_i
  end

  private

  def fetch_stats
    result = database.connection.exec_query(STATS_QUERY, "PgPeek::Table Stats", [ name ])
    result.first || empty_stats
  end

  def empty_stats
    {
      "table_name" => name,
      "seq_scan" => 0,
      "seq_tup_read" => 0,
      "idx_scan" => 0,
      "idx_tup_fetch" => 0,
      "n_tup_ins" => 0,
      "n_tup_upd" => 0,
      "n_tup_del" => 0,
      "n_live_tup" => 0,
      "n_dead_tup" => 0,
      "last_vacuum" => nil,
      "last_autovacuum" => nil,
      "last_analyze" => nil,
      "last_autoanalyze" => nil,
      "vacuum_count" => 0,
      "autovacuum_count" => 0,
      "analyze_count" => 0,
      "autoanalyze_count" => 0,
      "heap_blks_read" => 0,
      "heap_blks_hit" => 0,
      "idx_blks_read" => 0,
      "idx_blks_hit" => 0,
      "toast_blks_read" => 0,
      "toast_blks_hit" => 0,
      "tidx_blks_read" => 0,
      "tidx_blks_hit" => 0,
      "row_estimate" => 0
    }
  end
end
