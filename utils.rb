require 'fileutils'
require 'json'
require 'net/http'
require 'sqlite3'
require 'byebug'

module Utils
    def configs
        config = JSON.parse(open('./config.json', 'r').read) if config.nil?
        config
    end

    def prepare
        @http = Net::HTTP.new(@base_url.host, @base_url.port, configs['proxyhost'], configs['proxyport'])
        mk_save_path
        create_or_use_db
    end

    def save_to_db(post)
        thumb = get_thumb post
        insert = 'INSERT INTO posts values(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
        begin
            @db.execute insert, nil, post['id'], thumb, post['tags'], post['rating'],
                        post['score'], post['width'], post['height'], post['file_size'],
                        post['file_url'], post['author'], post['source']
            puts "#{post['id']} saved into database"
        rescue Exception => e
            puts e.message
            e.backtrace.each { |line| puts "\t" + line }
        end
    end

    def show_progress(id, size, read)
        @last_progress = '' if @last_progress.nil?
        delete_back = ''
        @last_progress.length.times do
            delete_back += "\b"
        end
        # debugger
        print delete_back
        @last_progress = "#{id}===>#{('%0.2f' % ((read.to_f / size.to_f) * 100))}%"
        print @last_progress
    end

    def prepare_show_next_progress
        print "\n"
        @last_progress = ''
    end

    def downloaded?(id)
        @downloaded_ids = get_all_downloaded_id if @downloaded_ids.nil?
        downloaded = @downloaded_ids.include? id
        puts "#{id} downloaded, skip!" if downloaded
        downloaded
    end

    def download(post)
        file_url = (post['file_url'].nil? ? post['url'] : post['file_url']).gsub(/^http:\/\/konachan\.com/, '')
        file_name = "#{(configs['tag'] + '_' unless configs['tag'].nil?)}#{'id.' + post['id'].to_s}#{'_' + post['height'].to_s + 'x' + post['width'].to_s}" +
                    file_url[file_url.length - 4, file_url.length - 1]
        dir = File.join(configs['path'], (configs['tag'].nil? ? 'images' : configs['tag']))
        Dir.mkdir dir unless Dir.exist?(dir)
        file_name = File.join(dir, post['rating'], file_name)
        request = Net::HTTP::Get.new file_url
        @http.request request do |response|
            open(file_name, 'w') do |io|
                file_size = response.content_length
                has_read = 0
                response.read_body do |stream|
                    io.write stream
                    has_read += stream.size
                    show_progress(post['id'], file_size, has_read)
                end
                prepare_show_next_progress
                io.close
            end
        end
    end

    private

    def create_or_use_db
        @db = SQLite3::Database.new(File.join(configs['path'], 'data.db'))
        @db.results_as_hash = true
        if @db.execute("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='posts'")[0][0] == 0
            creat_table = "CREATE TABLE posts(
                _id INTEGER PRIMARY KEY AUTOINCREMENT,
                id INTEGER NOT NULL UNIQUE,
                thumb BLOB,
                tags TEXT,
                rating TEXT,
                score INTEGER,
                width INTEGER,
                height INTEGER,
                size INTEGER,
                url TEXT,
                author TEXT,
                source TEXT
            )"
            @db.execute creat_table
        end
    end

    def mk_save_path
        path = configs['path']
        FileUtils.mkpath(path) if !path.nil? && !path.empty?
    end

    def get_all_downloaded_id
        ids = []
        result = @db.query 'SELECT id FROM posts'
        result.each { |id| ids << id[0] }
        ids
    end

    def get_thumb(post)
        thumb_request = Net::HTTP::Get.new post['preview_url'].gsub(/^http:\/\/konachan\.com/, '')
        thumb = @http.request thumb_request
        SQLite3::Blob.new thumb.read_body
    end
end
