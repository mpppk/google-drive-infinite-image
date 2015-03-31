require_relative 'google-drive-warapper'

CLIENT_ID     = ENV["GOOGLE_ID"]
CLIENT_SECRET = ENV["GOOGLE_SECRET"]
CMD           = ARGV[0]
SRC_DIR       = ARGV[1]
DST_DIR       = ARGV[2]

if CMD == "upload"
  begin
  	drive = GoogleDriveWarapper.new(CLIENT_ID, CLIENT_SECRET)
  	puts "uploading start from #{SRC_DIR}"
  	drive.upload_dir(SRC_DIR, DST_DIR == "mv")
  rescue Google::APIClient::AuthorizationError => ex
  	puts "session is disconnected. reconnecting..."
  	retry
  rescue Google::APIClient::ServerError => ex
  	puts ex
  	retry
  end
elsif CMD == "download"
  drive = GoogleDriveWarapper.new(CLIENT_ID, CLIENT_SECRET)
  puts "downloading start from #{SRC_DIR}"
  drive.download_img_dir(SRC_DIR, DST_DIR)
else
  puts "gdii: #{CMD} is not a gdii command. Use \"upload\" or \"download\"."
end
