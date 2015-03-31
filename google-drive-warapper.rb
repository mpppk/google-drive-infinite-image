require 'uri'
require 'net/http'
require 'oauth2'
require 'google_drive'
require 'cgi'
require 'pathname'
require 'nokogiri'
require 'open-uri'

# Save refresh token.
REFRESH_TOKEN_FILE_NAME = "refresh_token.txt"

# Support image downloading and uploading as google document.
class GoogleDriveWarapper
	# @param [String] client_id google app id
	# @param [String] client_secret google app secret
	def initialize(client_id, client_secret)
		@session = get_session
	end

	# show auth url and and Return refresh token"
	# This method will show URL for authorization.
	# Access the URL from your Browser.
	# Copy after "code=" in redirected URL.
	# Paste the code in terminal.
	# @return [String] refresh token
	def get_new_refresh_token
		client = OAuth2::Client.new(
			CLIENT_ID, CLIENT_SECRET,
			:site => "https://accounts.google.com",
			:token_url => "/o/oauth2/token",
			:authorize_url => "/o/oauth2/auth")

		auth_url = client.auth_code.authorize_url(
			:redirect_uri => "http://localhost",
			:scope =>
			"https://docs.google.com/feeds/ " +
			"https://docs.googleusercontent.com/ " +
			"https://spreadsheets.google.com/feeds/")

		puts auth_url

		print "authorization code:"
		authorization_code = STDIN.gets.chomp

		cmd = "curl -d client_id=#{CLIENT_ID} -d client_secret=#{CLIENT_SECRET} -d redirect_uri=http://localhost -d grant_type=authorization_code -d code=#{authorization_code} https://accounts.google.com/o/oauth2/token"
		JSON.parse( `#{cmd}` )["refresh_token"]
	end

	# Return refresh token.
	# If REFRESH_TOKEN_FILE exist, use this one.
	# Otherwise, create new refresh token.
	# @return [String] refresh token
	def get_refresh_token
		if File.exists?(REFRESH_TOKEN_FILE_NAME)
			return File.read(REFRESH_TOKEN_FILE_NAME, :encoding => Encoding::UTF_8)
		else
			return get_new_refresh_token
		end
	end

	# Return session object.
	# if REFRESH_TOKEN_FILE doesn't exist, create this one.
	# @return [GoogleDrive::Session]
	def get_session
		refresh_token = get_refresh_token

		client = OAuth2::Client.new(
		        CLIENT_ID,
		        CLIENT_SECRET,
		        site: "https://accounts.google.com",
		        token_url: "/o/oauth2/token",
		        authorize_url: "/o/oauth2/auth")
		auth_token = OAuth2::AccessToken.from_hash(client,{:refresh_token => refresh_token, :expires_at => 3600})
		auth_token = auth_token.refresh!
		session = GoogleDrive.login_with_oauth(auth_token.token)

		File.write(REFRESH_TOKEN_FILE_NAME, refresh_token) unless File.exists?(REFRESH_TOKEN_FILE_NAME)
		return session
	end

	# upload dir to google drive.
	# @param [string] dir_path Path of the directory to upload
	# @param [bool] move_flag When you make this flag to true, this method delete original file after upload
	# @param [GoogleDrive::Collection] collection collection of upload destination
	# @return [nil]
	def upload_dir(dir_path, move_flag = false, collection = @session.root_collection)
		dir_name = File.basename(dir_path).force_encoding("utf-8")
		puts dir_name
		if collection.subcollections.map{ |c| c.title }.include?( dir_name )
			puts "collection #{dir_name} already exist in google drive"
			new_collection = collection.subcollection_by_title( dir_name )
		else
			puts "collection created #{dir_name}"
			new_collection = collection.create_subcollection( dir_name )
		end

		entries_path = get_entries_path(dir_path)
		entries_path.each do |entry_path|
			entry_name = File.basename(entry_path)

			if FileTest.directory?(entry_path)
				subdir_name = File.basename(entry_path)
				upload_dir(entry_path, true, new_collection)
			else
				puts "file: #{entry_path}"
				# if file exist in target collection, cancel upload.
				if new_collection.files.map { |f| f.title }.include?(entry_name)
					puts "already exists"
					if move_flag
						File.delete entry_path
						puts "#{entry_path} is deleted."
					end
					next
				end

				file = @session.upload_from_file(entry_path)
				new_collection.add(file)
				@session.root_collection.remove(file)

				if move_flag
					File.delete entry_path
					puts "#{entry_path} is deleted."
				end
			end
		end

		# remove directory
		if move_flag
			Dir::rmdir(dir_path)
			puts "dir #{dir_path} is deleted."
		end
		nil
	end

	# Return array of entry path in target directory path.
	# @param [String] dir_path Target directory path.
	# @return [Array] Array of entry path.
	def get_entries_path(dir_path)
		entries_path = Dir.entries( dir_path )
		entries_path.delete("..")
		entries_path.delete(".")
		entries_path.map!{ |e| dir_path + "/" + e.force_encoding("utf-8") }
		entries_path
	end

	# Download google document as image.
	# Target google document must consist in one image.
	# @param [String] file_path Path of google document in google drive.
	# @param [String] dst_path Path of destination.
	# @param [String] img_ext Extention of target image.
	# @return [nil]
	def download_img_from_doc(file_path, dst_path, img_ext=".jpg")
		puts "downloading from #{file_path} to #{dst_path}"
		collection = get_collection_by_url( File.dirname(file_path) )
		file = collection.file_by_title(File.basename(file_path))

		# Download google document as html.
		html_file_path = "#{dst_path}/#{Pathname(file.title).sub_ext(".html")}"
		file.export_as_file(html_file_path)

		# Download image from html.
		img_url = get_img_url_from_html(html_file_path)
		img_path = Pathname(html_file_path).sub_ext(img_ext)
		save_img_from_url(img_url, img_path)

		# remove image.
		File.delete(html_file_path)
		nil
	end

	# Download google document in target directory as image.
	# @param [String] img_dir_path Path of target directory in google drive.
	# @param [String] dst_path Path of destination.
	# @return [nil]
	def download_img_dir(img_dir_path, dst_path)
		dst_path += ( "/" + File.basename(img_dir_path) ).gsub("//", "/")
		FileUtils.makedirs(dst_path)
		collection = get_collection_by_url( img_dir_path )
		collection.files do |file|
			if file.is_a?(GoogleDrive::Collection)
				new_img_dir_path = img_dir_path + "/" + file.title
				download_img_dir(new_img_dir_path, dst_path)
			else
				# ファイルは画像として保存する
				# TODO google documentかどうかのチェック
				file_path = (img_dir_path + "/" + file.title).gsub("//", "/")
				img_ext   = File.extname(file.title)
				if img_ext.empty?
					download_img_from_doc(file_path, dst_path)
				else
					download_img_from_doc(file_path, dst_path, img_ext)
				end
			end
		end
		nil
	end

	# Return URL of image in html.
	# HTML must consist in one image.
	# @param [String] html_path Path of HTML.
	# @return [String] URL of image.
	def get_img_url_from_html(html_path)
		f   = File.open(html_path)
		doc = Nokogiri::HTML(f)
		img_url = doc.css('img').attribute('src').value
		f.close
		img_url
	end

	# Save image from URL.
	# @param [String] img_url URL of image.
	# @param [String] dst_path Path of destination.
	# @return [nil]
	def save_img_from_url(img_url, dst_path)
		open(dst_path, 'wb') do |output|
	    open(img_url) do |data|
	      output.write(data.read)
	    end
	  end
		nil
	end

	# Return collection what match argument URL.
	# @param [String] url
	# @return [GoogleDrive::Collection] matched Collection.
	def get_collection_by_url(url)
		dirs_name  = url.split("/")
		collection = @session.root_collection
		dirs_name.each do |dir_name|
			collection = collection.subcollection_by_title(dir_name)
		end
		collection
	end
end
