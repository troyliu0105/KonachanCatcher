require 'net/http'
require 'json'
require 'sqlite3'
require 'byebug'
require 'fileutils'

class Konachan
    def initialize(tag = nil, width = nil, height = nil, save_dir = '')
        @base_url = URI.parse('http://konachan.com')
        @tag = tag
        @width = width
        @height = height
        @save_dir = save_dir
        FileUtils.mkpath(@save_dir) if @save_dir.length
        @http = Net::HTTP.new(@base_url.host, @base_url.port)
        @db = SQLite3::Database.new(File.join(@save_dir, 'data.db'))
        @last_progress = ''
        if @db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='post'").empty?
            creat_table = "CREATE TABLE posts(
                _id INTEGER PRIMARY KEY NOT NULL,
                id INTEGER NOT NULL,
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

    def begin_task
        current_index = 1 # 当前处理的页数
        post_url = URI('http://konachan.com/post')
        loop do
            post_url.query = URI.encode_www_form(params(current_index))
            request = Net::HTTP::Get.new(post_url)
            response = @http.request(request)
            if response.class == Net::HTTPOK
                body = response.body
                reg = Regexp.new('^ *Post\\.register\\((\\{.*\\})\\)', Regexp::IGNORECASE)
                post_array = []
                body.scan(reg) { |match| post_array.push JSON.parse(match[0]) }
                post_array.each do |post|
                    save_to_db post
                    file_url = post['file_url'].gsub(/^http:\/\/konachan\.com/, '')
                    file_name = "#{(@tag + '_' unless @tag.nil?)}#{'id.' + post['id'].to_s}#{'_' + post['height'].to_s + 'x' + post['width'].to_s}" +
                                file_url[file_url.length - 4, file_url.length - 1]
                    id = post['id']
                    dir = @tag.nil? ? 'images' : @tag
                    if !@tag.nil? && !Dir.exist?(File.join(@save_dir, @tag))
                        Dir.mkdir(File.join(@save_dir, @tag))
                    elsif @tag.nil? && !Dir.exist?(File.join(@save_dir, 'images'))
                        Dir.mkdir(File.join(@save_dir, 'images'))
                    end
                    file_name = File.join(@save_dir, dir, file_name)
                    download(id, file_url, file_name)
                end
            else
                break
            end
            current_index += 1
        end
        puts 'Task End!'
        @db.close
    end

    private

    def params(page)
        @hash = {}
        @hash[:page] = page
        @hash[:tags] = "#{(@tag + ' ') unless @tag.nil?}#{('width:' + @width.to_s + '..') unless @width.nil?} #{('height:' + @height.to_s + '..') unless @height.nil?}"
        @hash
    end

    def download(id, url, name)
        request = Net::HTTP::Get.new url
        @http.request request do |response|
            open(name, 'w') do |io|
                file_size = response.content_length
                has_read = 0
                response.read_body do |stream|
                    io.write stream
                    has_read += stream.size
                    show_progress(id, file_size, has_read)
                    # debugger
                end
                print "\n"
                @last_progress = ''
                io.close
            end
        end
    end

    def save_to_db(post)
        insert = "INSERT INTO posts values(
            ?,
            '#{post['id']}',
            '#{post['tags'].gsub(/["]/, '')}',
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
            puts e.backtrace.inspect, 'ERROR!'
        end
    end

    def show_progress(id, size, read)
        delete_back = ''
        @last_progress.length.times do
            delete_back += "\b"
        end
        # debugger
        print delete_back
        @last_progress = "#{id}===>#{('%0.2f' % ((read.to_f / size.to_f) * 100))}%"
        print @last_progress
    end
end

konachan = Konachan.new(nil, 2560, 1600, '/Volumes/Data/Konachan')
konachan.begin_task
