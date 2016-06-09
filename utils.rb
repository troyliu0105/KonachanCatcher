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
        mk_save_path
        create_or_use_db
    end

    def save_to_db(post)
        thumb = get_thumb post
        insert = 'INSERT INTO posts values(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
        begin
            @db.execute insert, nil, post['id'], thumb, post['tags'], post['rating'],
                        post['width'], post['height'], post['file_size'],
                        post['file_url'], post['author'], post['source']
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

    private

    def create_or_use_db
        @db = SQLite3::Database.new(File.join(configs['path'], 'data.db'))
        if @db.execute("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='posts'")[0][0] == 0
            creat_table = "CREATE TABLE posts(
                _id INTEGER PRIMARY KEY AUTOINCREMENT,
                id INTEGER NOT NULL UNIQUE,
                thumb BLOB,
                tags TEXT,
                rating TEXT,
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
