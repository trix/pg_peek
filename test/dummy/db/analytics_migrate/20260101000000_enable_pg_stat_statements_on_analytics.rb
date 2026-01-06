class EnablePgStatStatementsOnAnalytics < ActiveRecord::Migration[8.0]
  def up
    enable_extension "pg_stat_statements"
  end

  def down
    disable_extension "pg_stat_statements"
  end
end
