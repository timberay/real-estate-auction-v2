require "sqlite3"
require "fileutils"
require "shellwords"

class AuctionBackup
  class IntegrityError < StandardError; end

  DATABASES = %w[production production_cache production_queue production_cable].freeze
  DAILY_RETENTION_DAYS  = 14
  WEEKLY_RETENTION_DAYS = 28

  def initialize(base_dir: "/var/backups/auction", storage_dir: nil, clock: Time)
    @base_dir    = base_dir
    @storage_dir = storage_dir || Rails.root.join("storage").to_s
    @clock       = clock
  end

  # Returns the target directory path where backups were written.
  def call
    now       = @clock.current
    timestamp = now.strftime("%Y%m%d-%H%M%S")
    bucket    = now.sunday? ? "weekly" : "daily"
    target    = File.join(@base_dir, bucket, timestamp)

    FileUtils.mkdir_p(target)
    backup_to(target)
    rotate

    target
  end

  def backup_to(target_dir)
    DATABASES.each do |db_name|
      src = File.join(@storage_dir, "#{db_name}.sqlite3")
      dst = File.join(target_dir, "#{db_name}.sqlite3")

      unless File.exist?(src)
        Rails.logger.warn("[AuctionBackup] Source DB not found, skipping: #{src}")
        next
      end

      # src is escaped at the shell level; dst is single-quoted for sqlite3's
      # own dot-command parser, which splits on spaces and does NOT understand
      # backslash-escaped spaces (only single-quoted args work there).
      ok = system("sqlite3 #{Shellwords.escape(src)} \".backup '#{dst}'\"")
      raise "sqlite3 .backup failed for #{src}" unless ok

      verify_integrity!(dst)
    end
  end

  def verify_integrity!(path)
    db = SQLite3::Database.new(path)
    result = db.get_first_value("PRAGMA integrity_check")
    db.close

    return if result == "ok"

    raise IntegrityError, "Integrity check failed for #{path}: #{result}"
  rescue SQLite3::NotADatabaseException => e
    raise IntegrityError, "Not a valid SQLite database at #{path}: #{e.message}"
  end

  def rotate
    prune_older_than(File.join(@base_dir, "daily"),  DAILY_RETENTION_DAYS)
    prune_older_than(File.join(@base_dir, "weekly"), WEEKLY_RETENTION_DAYS)
  end

  private

  def prune_older_than(dir, days)
    return unless Dir.exist?(dir)

    cutoff = @clock.current - (days * 24 * 3600)
    Dir.each_child(dir) do |entry|
      full_path = File.join(dir, entry)
      next unless File.directory?(full_path)

      mtime = File.mtime(full_path)
      FileUtils.rm_rf(full_path) if mtime < cutoff # strictly older than cutoff
    end
  end
end
