local upload = require "resty.upload"
local cjson = require "cjson"

local chunk_size = 4096
local form = upload:new(chunk_size)
local conf = {max_size=1024000, allow_exts={'zip'}}
local file
local file_name
local unzip_file_dir
local filedirname
local dir = '/home/tinker/temp/upload/haixin/'  

if not form then
    ngx.say(cjson.encode({code=501, msg='form is null',desc='表单内容为空！'}))
end

--判断某个值是否在数组中
function in_array(v, tab)
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


function get_filename(str)  
    local filename = ngx.re.match(str,'(.+)filename="(.+)"(.*)')  
    if filename then   
        return filename[2]  
    end  
end

function get_extension(str)
    return str:match(".+%.(%w+)$")
end

function getdiskuse(str)
    local handle = io.popen("df -h | grep home |awk -F ' ' '{print $5}'")
    local result = handle:read("*a")
    handle:close()

    return  result

end

function getdiskspace()
    -- body
    local handle = io.popen("df -h | grep home |awk -F ' ' '{print $4}'")
    local result = handle:read("*a")
    return result
end

function file_unzip()
    ngx.log(ngx.ERR,"测试")
    os.execute('unzip '..file_name ..' -d' ..dir..'/'..filedirname)
end

form:set_timeout(1000)

while true do
    local typ, res, err = form:read() 
    -- ngx.say("read: ", cjson.encode({typ, res}))
    if not typ then
         ngx.say(cjson.encode({code=503, msg='failed to read',desc='读取form失败!'}))
         ngx.log(ngx.DEBUG,cjson.encode({typ, res}));
         return
    end
    -- ngx.log(ngx.ERR,cjson.encode({typ, res}));
    if typ == "header" then
        if res[1] == "Content-Disposition" then
            filename = get_filename(res[2])
            if filename then
                local extension = get_extension(filename)
                filedirname = string.gsub(filename, '.zip','')
                -- getLocalIP();
                if not extension then
                    ngx.say(cjson.encode({code=501, msg='未获取文件后缀', desc=res}))
                    return 
                end

                local status = os.execute('mkdir -p '..dir)
                if status ~= 0 then
                    ngx.say(cjson.encode({code=501, msg='创建目录失败'}))
                    return
                end 

                 if in_array(extension, conf.allow_exts) then
                    file_name = dir..filename
                    file = io.open(file_name, "w+")
                end 

                
                
            end
        end
        elseif typ == "body" then
            if file then
                file:write(res)            
        end
        elseif typ == "part_end" then
            if file then
                file:close()
                ngx.log(ngx.DEBUG,'close files end ')
                file = nil
        end
        elseif typ == "eof" then
            if file_name then 
                file_unzip()
                -- ngx.say(cjson.encode({code=200, msg='上传成功！',desc= file_name_arry, server_verison= server_verison, file_orign_name= orign_name_array,diskstatus= {diskuse=getdiskuse(),diskspace= getdiskspace()}}))
                ngx.say(cjson.encode({code=200,msg='上传解压成功',filedir='/haixin/'..filedirname}))
                ngx.log(ngx.DEBUG,'file_name' .. filedirname)
            else
                -- ngx.say(cjson.encode({code=509, msg='form name do not existed',desc='',server_verison= server_verison,file_orign_name= orign_name_array,diskstatus= {diskuse= getdiskuse(),diskspace= getdiskspace()}}))
                ngx.say(cjson.encode({code=500,msg='文件存在问题',filedir=filedirname}))
        end
        break
        else
            
        end
    end
