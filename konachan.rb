require 'net/http'
require 'json'
require 'sqlite3'
require 'byebug'

class Konachan

  def initialize(tag = nil, width = nil, height = nil, save_dir = nil)
    @base_url = URI.parse('http://konachan.com')
    @tag = tag
    @width = width
    @height = height
    @save_dir = save_dir
    @proxy = Net::HTTP.new(@base_url.host, @base_url.port, '127.0.0.1', 8118) #使用Privoxy转换shadowscoks的Socks代理为http代理，BUG：无法使用Socks
    @db = SQLite3::Database.new("data.db")
    @creat_table = ""
    @last_progress = ""
  end

  def begin_task
    current_index = 1 #当前处理的页数
    post_url = URI('http://konachan.com/post')
    loop do
      post_url.query = URI.encode_www_form(params(current_index))
      request = Net::HTTP::Get.new(post_url)
      response = @proxy.request(request)
      if response.class == Net::HTTPOK
        body = response.body
        reg = Regexp.new("^\s*Post\\.register\\((\\{.*\\})\\)", Regexp::IGNORECASE)
        post_array = []
        body.scan(reg) { |match| post_array.push JSON.parse(match[0]) }
        post_array.each do |post|
          save_to_db post
          file_url = post["file_url"].gsub(/^http:\/\/konachan\.com/,'')
          file_name = "#{(@tag + "_" unless @tag.nil?)}#{"id." + post["id"].to_s}#{"_" + post["height"].to_s + "x" + post["width"].to_s}" +
                      file_url[file_url.length - 4, file_url.length - 1]
          id = post["id"]
          dir = @tag
          if (!@tag.nil? & !Dir.exist?(@tag))
            Dir.mkdir(@tag)
          elsif @tag.nil?
            Dir.mkdir("images")
            dir = 'images'
          end
          file_name = File.join(dir, file_name)
          download(id, file_url, file_name)
        end
      else
        break
      end
      current_index += 1
    end
    puts "Task End!"
    @db.close
  end

  private
  def params(page)
    @hash = Hash.new
    @hash[:page] = page
    @hash[:tags] = "#{@tag} width:#{@width}.. height:#{@height}.."
    @hash
  end

  def download(id, url, name)
    request = Net::HTTP::Get.new url
    @proxy.request request do |response|
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
        @last_progress = ""
        io.close
      end
    end
  end

  def save_to_db(post)
    if (@creat_table.size == 0) & (@db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='post'").size == 0)
      @creat_table = "create table post("
      post.each_key {|key| @creat_table = @creat_table + key + ","}
      @creat_table = @creat_table[0, @creat_table.length - 1] + ")"
      @db.execute @creat_table
    end
    insert = "insert into post values("
    post.each_value {|value| insert = insert + "'#{value.to_s}'" + ","}
    insert = insert[0, insert.length - 1] + ")"
    @db.execute insert
  end

  def show_progress(id, size, read)
    delete_back = ""
    @last_progress.length.times do
      delete_back += "\b"
    end
    # debugger
    print delete_back
    @last_progress = "#{id.to_s}===>#{("%0.2f" % ((read.to_f / size.to_f) * 100))}%"
    print @last_progress
  end

end


konachan = Konachan.new("black", 2560, 1600)
konachan.begin_task
