# KonachanCather

现在还处于alpha阶段，只有最基本的功能

## Function

1. 根据参数，下载网站上所有数量的图片到制定目录
2. 保存已下载信息至数据库
3. 重新启动下载后，跳过已下载的图片

## Useage

`config.json` 目前支持的参数有

- `tag`：搜索关键字
- `width`：大于此宽度
- `height`：大于此高度
- `rating`：评级（ safe，questionable，explicit，questionableplus，questionableless）

运行`ruby konachan.rb`来启动任务 (有的地区可能需要制定代理或者直接使用proxychains)

## Implementation

首先对`http://konachan.com/post`提交搜索请求，再依次解析并下载每一页的壁纸。壁纸信息的插入是由类似如下的JavaScript代码插入。（相比直接解析HTML而言可以获得更多信息）

```javascript
Post.register({"id":222627,"tags":"hatsune_miku red_flowers vocaloid",
"created_at":1465435563,"creator_id":156425,"author":"RyuZU","change":1081631,
"source":"http:\/\/www.pixiv.net\/member_illust.php?mode=medium\u0026illust_id=57301698",
"score":3,"md5":"877245192f68ace6b6ce2d3f68d7cc7a","file_size":5216153,
"file_url":"http:\/\/konachan.com\/image\/877245192f68ace6b6ce2d3f68d7cc7a\/Konachan.com%20-%20222627%20hatsune_miku%20red_flowers%20vocaloid.jpg",
"is_shown_in_index":true,"preview_url":"http:\/\/konachan.com\/data\/preview\/87\/72\/877245192f68ace6b6ce2d3f68d7cc7a.jpg",
"preview_width":150,"preview_height":113,"actual_preview_width":300,
"actual_preview_height":225,"sample_url":"http:\/\/konachan.com\/sample\/877245192f68ace6b6ce2d3f68d7cc7a\/Konachan.com%20-%20222627%20sample.jpg",
"sample_width":1500,"sample_height":1125,"sample_file_size":1291660,
"jpeg_url":"http:\/\/konachan.com\/image\/877245192f68ace6b6ce2d3f68d7cc7a\/Konachan.com%20-%20222627%20hatsune_miku%20red_flowers%20vocaloid.jpg",
"jpeg_width":3200,"jpeg_height":2400,"jpeg_file_size":0,"rating":"s",
"has_children":false,"parent_id":null,"status":"pending","width":3200,
"height":2400,"is_held":false,"frames_pending_string":"","frames_pending":[],
"frames_string":"","frames":[],"flag_detail":null})
```

所以，使用正则表达式对HTML进行搜寻，并找到下载地址进行下载。

## todo

- [x] ~~增加启动命令(代理，tag，长宽)~~ 使用config.json代替
- [ ] 加入出错重试
- [ ] 多线程 ~~误~~
- [x] 在下次继续下载时，跳过重复的图片
