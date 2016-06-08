require 'net/http'
require 'byebug'

require './utils'

class Konachan
    include Utils

    def initialize
        @base_url = URI.parse('http://konachan.com')
        @tag = configs['tag']
        @rating = configs['rating']
        @width = configs['width']
        @height = configs['height']
        @save_dir = configs['path']
        @http = Net::HTTP.new(@base_url.host, @base_url.port)
        prepare
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
                    id = post['id']
                    next if downloaded? id
                    file_url = post['file_url'].gsub(/^http:\/\/konachan\.com/, '')
                    file_name = "#{(@tag + '_' unless @tag.nil?)}#{'id.' + post['id'].to_s}#{'_' + post['height'].to_s + 'x' + post['width'].to_s}" +
                                file_url[file_url.length - 4, file_url.length - 1]
                    dir = File.join(@save_dir, (@tag.nil? ? 'images' : @tag))
                    Dir.mkdir dir unless Dir.exist?(dir)
                    file_name = File.join(dir, file_name)
                    download(id, file_url, file_name)
                    save_to_db post
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
        @hash[:tags] = "#{(@tag + ' ') unless @tag.nil?}#{('width:' + @width.to_s + '.. ') unless @width.nil?}#{('height:' + @height.to_s + '.. ') unless @height.nil?}#{('rating:' + @rating) unless @rating.nil?}"
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
                prepare_show_next_progress
                io.close
            end
        end
    end
end

konachan = Konachan.new
konachan.begin_task
