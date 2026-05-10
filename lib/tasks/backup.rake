namespace :db do
  desc "Backup all production SQLite databases with integrity check and daily/weekly rotation"
  task backup: :environment do
    target = AuctionBackup.new.call
    puts "Backup written to #{target}"
  end
end
