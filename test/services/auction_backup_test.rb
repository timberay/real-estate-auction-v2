require "test_helper"
require "tmpdir"
require "fileutils"
require "sqlite3"

class AuctionBackupTest < ActiveSupport::TestCase
  BACKUP_DBS = %w[production production_cache production_queue production_cable].freeze

  def setup
    @tmpdir = Dir.mktmpdir("auction_backup_test")
    @source_dir = Dir.mktmpdir("auction_backup_source")

    # Create minimal valid SQLite databases in source dir
    BACKUP_DBS.each do |db_name|
      path = File.join(@source_dir, "#{db_name}.sqlite3")
      SQLite3::Database.new(path) do |db|
        db.execute("CREATE TABLE IF NOT EXISTS _healthcheck (id INTEGER PRIMARY KEY)")
      end
    end
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
    FileUtils.rm_rf(@source_dir)
  end

  # --- Daily backup path ---

  test "call on a weekday creates a daily subdirectory" do
    clock = fixed_clock(Time.new(2026, 5, 11, 4, 0, 0)) # Monday
    backup = AuctionBackup.new(base_dir: @tmpdir, storage_dir: @source_dir, clock: clock)
    target = backup.call

    assert target.start_with?(File.join(@tmpdir, "daily")), "Expected daily/ prefix, got: #{target}"
    assert Dir.exist?(target), "Target directory should exist"
  end

  test "daily backup creates sqlite3 files for all 4 databases" do
    clock = fixed_clock(Time.new(2026, 5, 11, 4, 0, 0))
    backup = AuctionBackup.new(base_dir: @tmpdir, storage_dir: @source_dir, clock: clock)
    target = backup.call

    BACKUP_DBS.each do |db_name|
      path = File.join(target, "#{db_name}.sqlite3")
      assert File.exist?(path), "Expected #{db_name}.sqlite3 in #{target}"
      assert File.size(path) > 0, "#{db_name}.sqlite3 should not be empty"
    end
  end

  # --- Weekly backup path ---

  test "call on a Sunday creates a weekly subdirectory" do
    clock = fixed_clock(Time.new(2026, 5, 10, 4, 0, 0)) # Sunday
    backup = AuctionBackup.new(base_dir: @tmpdir, storage_dir: @source_dir, clock: clock)
    target = backup.call

    assert target.start_with?(File.join(@tmpdir, "weekly")), "Expected weekly/ prefix, got: #{target}"
  end

  # --- Integrity check ---

  test "integrity check passes for a valid SQLite backup" do
    clock = fixed_clock(Time.new(2026, 5, 11, 4, 0, 0))
    backup = AuctionBackup.new(base_dir: @tmpdir, storage_dir: @source_dir, clock: clock)
    target = backup.call

    # Should not raise
    BACKUP_DBS.each do |db_name|
      path = File.join(target, "#{db_name}.sqlite3")
      assert_nothing_raised { backup.verify_integrity!(path) }
    end
  end

  test "integrity check raises for a corrupted file" do
    clock = fixed_clock(Time.new(2026, 5, 11, 4, 0, 0))
    backup = AuctionBackup.new(base_dir: @tmpdir, storage_dir: @source_dir, clock: clock)

    corrupted = File.join(@tmpdir, "corrupted.sqlite3")
    File.write(corrupted, "this is not a valid sqlite3 file at all!!!")

    assert_raises(AuctionBackup::IntegrityError) { backup.verify_integrity!(corrupted) }
  end

  # --- Rotation ---

  test "rotation removes daily subdirs older than 14 days" do
    frozen_now = Time.new(2026, 5, 11, 4, 0, 0)
    clock = fixed_clock(frozen_now)
    backup = AuctionBackup.new(base_dir: @tmpdir, storage_dir: @source_dir, clock: clock)

    # Create fake old and recent daily dirs
    old_dir = File.join(@tmpdir, "daily", "20260425-040000")
    recent_dir = File.join(@tmpdir, "daily", "20260510-040000")
    FileUtils.mkdir_p(old_dir)
    FileUtils.mkdir_p(recent_dir)

    old_time = frozen_now - (15 * 24 * 3600) # 15 days before frozen clock
    recent_time = frozen_now - (3 * 24 * 3600) # 3 days before frozen clock
    File.utime(old_time, old_time, old_dir)
    File.utime(recent_time, recent_time, recent_dir)

    backup.rotate

    refute Dir.exist?(old_dir), "Old daily dir should have been removed"
    assert Dir.exist?(recent_dir), "Recent daily dir should be kept"
  end

  test "rotation removes weekly subdirs older than 28 days" do
    frozen_now = Time.new(2026, 5, 11, 4, 0, 0)
    clock = fixed_clock(frozen_now)
    backup = AuctionBackup.new(base_dir: @tmpdir, storage_dir: @source_dir, clock: clock)

    old_dir = File.join(@tmpdir, "weekly", "20260405-040000")
    recent_dir = File.join(@tmpdir, "weekly", "20260501-040000")
    FileUtils.mkdir_p(old_dir)
    FileUtils.mkdir_p(recent_dir)

    old_time = frozen_now - (29 * 24 * 3600) # 29 days before frozen clock
    recent_time = frozen_now - (5 * 24 * 3600) # 5 days before frozen clock
    File.utime(old_time, old_time, old_dir)
    File.utime(recent_time, recent_time, recent_dir)

    backup.rotate

    refute Dir.exist?(old_dir), "Old weekly dir should have been removed"
    assert Dir.exist?(recent_dir), "Recent weekly dir should be kept"
  end

  test "rotation keeps daily dirs that are under 14 days old (boundary)" do
    frozen_now = Time.new(2026, 5, 11, 4, 0, 0)
    clock = fixed_clock(frozen_now)
    backup = AuctionBackup.new(base_dir: @tmpdir, storage_dir: @source_dir, clock: clock)

    boundary_dir = File.join(@tmpdir, "daily", "20260428-040000")
    FileUtils.mkdir_p(boundary_dir)

    # 13 days before frozen clock — should be kept (cutoff is > 14 days)
    boundary_time = frozen_now - (13 * 24 * 3600)
    File.utime(boundary_time, boundary_time, boundary_dir)

    backup.rotate

    assert Dir.exist?(boundary_dir), "13-day-old dir should be kept"
  end

  # --- Path with spaces (sqlite3 dot-command single-quote coverage) ---

  test "backup succeeds when target path contains a space" do
    # Dir.mktmpdir's prefix is sanitized on Linux (spaces stripped), so we must
    # build the space-containing path explicitly. The *destination* (base_dir)
    # flows into the sqlite3 .backup dot-command — that is what we are testing.
    parent = Dir.mktmpdir("auction_space_test")
    base_with_space = File.join(parent, "auction backup root")
    FileUtils.mkdir_p(base_with_space)

    begin
      BACKUP_DBS.each do |db_name|
        path = File.join(@source_dir, "#{db_name}.sqlite3")
        # Source DBs are already created in setup; skip if already present.
        next if File.exist?(path)

        SQLite3::Database.new(path) do |db|
          db.execute("CREATE TABLE IF NOT EXISTS _healthcheck (id INTEGER PRIMARY KEY)")
        end
      end

      clock = fixed_clock(Time.new(2026, 5, 12, 4, 0, 0)) # Tuesday
      backup = AuctionBackup.new(base_dir: base_with_space, storage_dir: @source_dir, clock: clock)
      result = backup.call

      BACKUP_DBS.each do |db_name|
        path = File.join(result, "#{db_name}.sqlite3")
        assert File.exist?(path), "backup file should be created in space-containing path: #{path}"
      end
    ensure
      FileUtils.rm_rf(parent)
    end
  end

  # --- Rotation uses injected clock for cutoff ---

  test "rotation cutoff is computed from injected clock, not wall clock" do
    # Fix the clock at a specific moment so the test is deterministic.
    frozen_now = Time.new(2026, 5, 11, 4, 0, 0)
    clock = fixed_clock(frozen_now)
    backup = AuctionBackup.new(base_dir: @tmpdir, storage_dir: @source_dir, clock: clock)

    daily_dir = File.join(@tmpdir, "daily")
    # One dir whose mtime is 15 days before the frozen clock → should be pruned
    old_dir = File.join(daily_dir, "20260426-040000")
    # One dir whose mtime is 3 days before the frozen clock → should be kept
    new_dir = File.join(daily_dir, "20260508-040000")
    FileUtils.mkdir_p(old_dir)
    FileUtils.mkdir_p(new_dir)

    old_mtime = frozen_now - (15 * 24 * 3600)
    new_mtime  = frozen_now - (3  * 24 * 3600)
    File.utime(old_mtime, old_mtime, old_dir)
    File.utime(new_mtime,  new_mtime,  new_dir)

    backup.rotate

    refute Dir.exist?(old_dir), "Dir 15 days before frozen_now should be pruned"
    assert Dir.exist?(new_dir),  "Dir 3 days before frozen_now should be kept"
  end

  # --- Missing source DB ---

  test "missing source database is skipped silently" do
    partial_source_dir = Dir.mktmpdir("partial_source")
    # Only create 2 of 4 DBs
    %w[production production_cache].each do |db_name|
      path = File.join(partial_source_dir, "#{db_name}.sqlite3")
      SQLite3::Database.new(path) do |db|
        db.execute("CREATE TABLE IF NOT EXISTS _healthcheck (id INTEGER PRIMARY KEY)")
      end
    end

    clock = fixed_clock(Time.new(2026, 5, 11, 4, 0, 0))
    backup = AuctionBackup.new(base_dir: @tmpdir, storage_dir: partial_source_dir, clock: clock)

    assert_nothing_raised { backup.call }
    FileUtils.rm_rf(partial_source_dir)
  end

  private

  def fixed_clock(time)
    Object.new.tap do |obj|
      obj.define_singleton_method(:current) { time }
    end
  end
end
