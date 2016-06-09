require 'fileutils'
require 'json'
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
        insert = "INSERT INTO posts values(
            ?,
            '#{post['id']}',
            '#{post['tags'].gsub(/["']/, '')}',
            '#{post['author']}',
            '#{post['source']}',
            '#{post['file_size']}',
            '#{post['file_url']}',
            '#{post['width']}',
            '#{post['height']}'
        )" # 对tags进行去掉 “ 的操作，避免插入失败
        begin
            @db.execute insert
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
                _id INTEGER PRIMARY KEY NOT NULL,
                id INTEGER NOT NULL UNIQUE,
                tags TEXT,
                author TEXT,
                source TEXT,
                size INTEGER,
                url TEXT,
                width INTEGER,
                height INTEGER
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
end
