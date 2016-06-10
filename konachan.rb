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
                    next if downloaded? post['id']
                    download post unless configs['infoonly']
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

    def begin_task_from_db
        result = @db.execute 'SELECT * FROM posts ORDER BY score DESC'
        result.each do |post|
            download post
        end
    end

    private

    def params(page)
        @hash = {} if @hash.nil?
        @hash[:page] = page
        @hash[:tags] = "#{(@tag + ' ') unless @tag.nil?}#{('width:' + @width.to_s + '.. ') unless @width.nil?}#{('height:' + @height.to_s + '.. ') unless @height.nil?}#{('rating:' + @rating) unless @rating.nil?}" if @hash[:tags].nil?
        @hash
    end
end

konachan = Konachan.new
if configs['from_db']
    konachan.begin_task_from_db
else
    konachan.begin_task
end
