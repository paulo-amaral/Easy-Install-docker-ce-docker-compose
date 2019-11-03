local tkg = {}
-- 是否在队列中
-- 返回位置
function tkg.in_array(v, tab)
    local i = false
    local temp = string.lower(v)
    for _, val in ipairs(tab) do
        if val == temp then
            i = true
            break
        end
    end
    return i
end


-- 生成 uuid
function tkg.uuid2()
     local template ="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
     local d = io.open("/dev/urandom", "r"):read(4)
     math.randomseed(os.time() + d:byte(1) + (d:byte(2) * 256) + (d:byte(3) * 65536) + (d:byte(4) * 4294967296))
     return string.gsub(template, "x", function (c)
      local v = (c == "x") and math.random(0, 0xf) or math.random(8, 0xb)
      return string.format("%x", v)
      end)
end

-- 获取文件名
function tkg.getFilename(str)
    if not str then
        return nil
    end  
    local filename = ngx.re.match(str,'(.+)filename="(.+)"(.*)')  
    if filename then   
        return filename[2]  
    end
    return nil  
end


function tkg.getFileRealName(str)
	if(string.find(str,"/")) then  
		if(str) then
			local name = string.gsub(str,"\\","/");
			return name:match(".+/(.+)$");
		else
			return "default-file-name";
		end
	else
		return  str
	end

end

-- 或缺后缀
function tkg.get_extension(str)
    return str:match(".+%.(%w+)$")
end

-- 磁盘用量
function tkg.getdiskuse()
	local handle = io.popen("df -h | grep home |awk -F ' ' '{print $5}'")
	local result = handle:read("*a")
	handle:close()
    return result
end

-- 磁盘剩余空间
function tkg.getdiskspace()
    -- body
    local handle = io.popen("df -h | grep home |awk -F ' ' '{print $4}'")
    local result = handle:read("*a")
    return result
end

-- GET的请求数据比较简单
function tkg.get(self)
    local  getArgs = {}
    getArgs = ngx.req.get_uri_args()
    return getArgs
end

-- POST(urlencoded) 请求
-- urlencoded类型的POST请求数据也比较简单
function tkg.post_urlencoded(self)
    local  postArgs = {}
    postArgs = ngx.req.get_post_args()
    return postArgs
end


-- POST(form-data) 请求
-- form-data类型的POST请求数据就比较复杂，需要进行字符串分割(lua好像不带split方法)，所以首先要写一个split方法
function tkg.split(mainString, delim)

    if type(delim) ~= "string" or string.len(delim) <= 0 then
        return nil
    end
 
    local start = 1
    local t = {}
    while true do
        ngx.log(ngx.ERR,type(mainString))
        local pos = string.find (mainString, delim, start, true) -- plain find
        if not pos then
            break
        end
        table.insert (t, string.sub (mainString, start, pos - 1))
        start = pos + string.len (delim)
    end

    table.insert (t, string.sub (mainString, start))
 
    return t
end

-- 另外一个split方法 实现方式的
function tkg.tsplit(inputstr,sep)
    -- ngx.log(ngx.ERR,type(inputstr))
    if sep == nil then
            sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
            table.insert(t, str)
    end
    return t
end

-- table 转成 string
function tkg.table_to_string(tbl)
    local result = "{"
    for k, v in pairs(tbl) do
        -- Check the key type (ignore any numerical keys - assume its an array)
        if type(k) == "string" then
            result = result.."[\""..k.."\"]".."="
        end

        -- Check the value type
        if type(v) == "table" then
            result = result..table_to_string(v)
        elseif type(v) == "boolean" then
            result = result..tostring(v)
        else
            result = result.."\""..v.."\""
        end
        result = result..","
    end
    -- Remove leading commas from the result
    if result ~= "" then
        result = result:sub(1, result:len()-1)
    end
    return result.."}"
end



-- 获取form-data的请求参数需要用到upload库来获取表单，这个库安装openresty默认已经带了，也可以上GITHUB下载最新版本
-- args = tkg:post_form_data(form, err)

-- read: ["header",["Content-Disposition","form-data; name=\"file1\"; filename=\"a.txt\"","Content-Disposition: form-data; name=\"file1\"; filename=\"a.txt\""]]
-- read: ["header",["Content-Type","text\/plain","Content-Type: text\/plain"]]
-- read: ["body","Hello"]
-- read: ["body",", wor"]
-- read: ["body","ld"]
-- read: ["part_end"]
-- read: ["header",["Content-Disposition","form-data; name=\"test\"","Content-Disposition: form-data; name=\"test\""]]
-- read: ["body","value"]
-- read: ["body","\r\n"]
-- read: ["part_end"]
-- read: ["eof"]
-- read: ["eof"]z
function tkg.post_form_data(form,err)
    local cjson = require "cjson"

    if not form then
        ngx.log(ngx.ERR, "failed to new upload: ", err)
        return {}
    end

    form:set_timeout(1000) -- 1 sec
    local paramTable = {["s"]=1}
    local tempkey = ""
    while true do
        local i =1 ;
        local typ, res, err = form:read()
        if not typ then
            ngx.log(ngx.ERR, "failed to read: ", err)
            return {}
        end
        local key = ""
        local value = ""
        if typ == "header" then
            local key_res = tkg.tsplit(res[2],";")
            ngx.log(ngx.ERR,cjson.encode({"key_res",key_res}))
            local key_name = key_res[2]
            if type(key_name) ~= 'table' and key_name ~= nil then 
                key_res = tkg.tsplit(key_name,"=")
                if key[2] ~= nil  and type(key[2]) ~= 'table' then 
                    -- goto continue
                    key = (string.gsub(key_res[2],"\"",""))
                    paramTable[key] = ""
                    tempkey = key
                end
            end
            
        end
        if typ == "body" then
            value = res
            if paramTable.s ~= nil then paramTable.s = nil end
            paramTable[tempkey] = value
            ngx.log(ngx.ERR,cjson.encode({"body",value}))

        end
        if typ == "eof" then
            break
        end
        -- ::continue::
    end
    return paramTable
end


-- demo: 根据请求类型不同使用不同方法进行获取
-- 根据需要，也可以将其合并起来
function tkg.new()
    local args = {}
    local requestMethod = ngx.var.request_method
    local receiveHeaders = ngx.req.get_headers()
    local upload = require "resty.upload"
    local form, err = upload:new(chunk_size)

    if "GET" == requestMethod then
        args = tkg:get()
    elseif "POST" == requestMethod then
        ngx.req.read_body()
        if string.sub(receiveHeaders["content-type"],1,20) == "multipart/form-data;" then
            args = tkg:post_form_data(form, err)
        else
            args = tkg:post_urlencoded()
        end
    end

    return args
end



function tkg.loadFormInput (form)
    local stringy = require "stringy" 
    local result = {
        data = {},
        indexes = {}
    }
    local part_index = 1
    local part_name, part_value

    -- Should be set to 4096 or 8192 for real-world settings

    if not form then
        -- There is no form data to read from
        return nil
    end

    while true do
        local typ, res, err = form:read()
        if not typ then
            return nil -- An error happened, 'failed to read'
        end
        local cjson = require "cjson"
        -- ngx.log(ngx.ERR,cjson.encode({{typ,res},{"err:",err}}))
        if typ == "header" then
            if stringy.startswith(string.lower(res[1]), "content-disposition") then
                local parts = stringy.split(res[3], ";")
                local current_parts = stringy.split(stringy.strip(parts[2]), "=")
                if string.lower(table.remove(current_parts, 1)) == "name" then
                    local current_value = stringy.strip(table.remove(current_parts, 1))
                    part_name = string.sub(current_value, 2, string.len(current_value) - 1)
                end
            end
        elseif typ == "body" then
            part_value = res
        elseif typ == "part_end" then
            if part_name ~= nil and part_name ~= "file_entity" then
                result.data[part_index] = {
                    name = part_name,
                    value = part_value
                }

                result.indexes[part_name] = part_index

                -- Reset fields for the next part
                part_value = nil
                part_name = nil
                part_index = part_index + 1
            end
        elseif typ == "eof" then
            -- finish reading the input
            break
        else
            -- do nothing
        end
    end

    return result
end

function tkg.getParam(args,param_name)
    local indexes = args.indexes;
    local param_index = indexes[param_name];
    if param_index ~= nil  then 
        return args.data[param_index].value;
    end
    return nil;
end
return tkg