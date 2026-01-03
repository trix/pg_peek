require "test_helper"

class PgPeek::TableTest < ActiveSupport::TestCase
  setup do
    @database = PgPeek::Database.find("primary")
    @table = PgPeek::Table.new(@database, "posts")
  end

  test "exists? returns true for existing table" do
    assert @table.exists?
  end

  test "exists? returns false for non-existing table" do
    table = PgPeek::Table.new(@database, "nonexistent_table")
    assert_not table.exists?
  end

  test "find returns table when it exists" do
    table = PgPeek::Table.find(@database, "posts")
    assert_not_nil table
    assert_equal "posts", table.name
  end

  test "find returns nil when table does not exist" do
    table = PgPeek::Table.find(@database, "nonexistent_table")
    assert_nil table
  end

  test "stats returns hash with all expected keys" do
    stats = @table.stats

    expected_keys = %w[
      table_name seq_scan seq_tup_read idx_scan idx_tup_fetch
      n_tup_ins n_tup_upd n_tup_del n_live_tup n_dead_tup
      last_vacuum last_autovacuum last_analyze last_autoanalyze
      vacuum_count autovacuum_count analyze_count autoanalyze_count
      heap_blks_read heap_blks_hit idx_blks_read idx_blks_hit
      toast_blks_read toast_blks_hit tidx_blks_read tidx_blks_hit
      row_estimate
    ]

    expected_keys.each do |key|
      assert stats.key?(key), "Expected stats to have key '#{key}'"
    end
  end

  test "cache_hit_ratio returns nil when no activity" do
    ratio = PgPeek::Table.cache_hit_ratio(0, 0)
    assert_nil ratio
  end

  test "cache_hit_ratio calculates correct percentage" do
    ratio = PgPeek::Table.cache_hit_ratio(95, 5)
    assert_equal 95.0, ratio
  end

  test "cache_hit_ratio returns 100 when all hits" do
    ratio = PgPeek::Table.cache_hit_ratio(100, 0)
    assert_equal 100.0, ratio
  end

  test "cache hit ratio methods return values" do
    # These may be nil or numeric depending on table activity
    assert_respond_to @table, :heap_cache_hit_ratio
    assert_respond_to @table, :index_cache_hit_ratio
    assert_respond_to @table, :toast_cache_hit_ratio
    assert_respond_to @table, :toast_index_cache_hit_ratio
  end

  test "row stats return integers" do
    assert_kind_of Integer, @table.seq_scan
    assert_kind_of Integer, @table.idx_scan
    assert_kind_of Integer, @table.rows_fetched
    assert_kind_of Integer, @table.rows_inserted
    assert_kind_of Integer, @table.rows_updated
    assert_kind_of Integer, @table.rows_deleted
    assert_kind_of Integer, @table.live_tuples
    assert_kind_of Integer, @table.dead_tuples
  end

  test "scan percentages are nil or numeric" do
    # May be nil if no scans have occurred
    seq_pct = @table.seq_scan_percentage
    idx_pct = @table.idx_scan_percentage

    if @table.total_scans > 0
      assert_kind_of Numeric, seq_pct
      assert_kind_of Numeric, idx_pct
      assert_in_delta 100.0, seq_pct + idx_pct, 0.1
    else
      assert_nil seq_pct
      assert_nil idx_pct
    end
  end

  test "dead_tuple_ratio is nil or numeric" do
    ratio = @table.dead_tuple_ratio

    if @table.live_tuples + @table.dead_tuples > 0
      assert_kind_of Numeric, ratio
      assert ratio >= 0
      assert ratio <= 100
    else
      assert_nil ratio
    end
  end

  test "dead_tuple_warning? returns boolean" do
    assert_includes [ true, false ], @table.dead_tuple_warning?
  end

  test "vacuum stats return correct types" do
    assert_kind_of Integer, @table.vacuum_count
    assert_kind_of Integer, @table.autovacuum_count
    assert_kind_of Integer, @table.analyze_count
    assert_kind_of Integer, @table.autoanalyze_count

    # Timestamps may be nil or Time
    [ :last_vacuum, :last_autovacuum, :last_analyze, :last_autoanalyze ].each do |method|
      value = @table.send(method)
      assert(value.nil? || value.is_a?(Time), "#{method} should be nil or Time, got #{value.class}")
    end
  end

  test "inline_stats_for returns hash keyed by table name" do
    stats = PgPeek::Table.inline_stats_for(@database, [ "posts" ])

    assert_kind_of Hash, stats
    assert stats.key?("posts"), "Expected stats to contain 'posts' key"

    table_stats = stats["posts"]
    assert table_stats.key?(:heap_hit_ratio)
    assert table_stats.key?(:index_hit_ratio)
  end

  test "inline_stats_for returns empty hash for empty array" do
    stats = PgPeek::Table.inline_stats_for(@database, [])
    assert_equal({}, stats)
  end

  test "excluded? returns true for default excluded tables" do
    assert PgPeek::Table.excluded?("schema_migrations")
    assert PgPeek::Table.excluded?("ar_internal_metadata")
  end

  test "excluded? returns false for regular tables" do
    assert_not PgPeek::Table.excluded?("posts")
    assert_not PgPeek::Table.excluded?("users")
  end

  test "excluded? works with regex patterns" do
    original_excluded = PgPeek.config.excluded_tables.dup

    PgPeek.config.excluded_tables = [ /^test_/ ]
    assert PgPeek::Table.excluded?("test_table")
    assert PgPeek::Table.excluded?("test_other")
    assert_not PgPeek::Table.excluded?("posts")
  ensure
    PgPeek.config.excluded_tables = original_excluded
  end

  test "stats_reset_at returns a time or nil" do
    reset_at = @table.stats_reset_at
    assert(reset_at.nil? || reset_at.is_a?(Time), "stats_reset_at should be nil or Time")
  end

  test "seconds_since_reset returns numeric or nil" do
    seconds = @table.seconds_since_reset

    if @table.stats_reset_at
      assert_kind_of Numeric, seconds
      assert seconds >= 0
    else
      assert_nil seconds
    end
  end

  test "stats are memoized" do
    stats1 = @table.stats
    stats2 = @table.stats
    assert_same stats1, stats2
  end
end
