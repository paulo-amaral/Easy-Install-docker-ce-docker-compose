local upload = require "resty.upload"
local cjson = require "cjson"
-- local lfs = require "lfs"
local tkg = require "tkg"
local chunk_size = 4096
local form = upload:new(chunk_size)
local conf = {fileHome='/home/tinker/temp/upload/',version=1010,allow_exts={'mpeg','mov','pdf','doc','zip','swf','jar','xls','docx','xlsx','pptx','avi','mp4','tiff','3gp','wmv','apk','exe','tar'}}



local function getFileSecondPath(params)
    -- local form_data = form
   
    return os.date('%Y')..os.date('%m')..os.date('%d')..'/';
end

local function getFormParams(allParam,param)
    local param_value  = tkg.getParam(allParam,param)
    if param_value ~= nil then 
        return param_value
    end
    return nil
end

local function uploadHandle()
    local disk_status = {diskuse=tkg.getdiskuse(),diskspace= tkg.getdiskspace()}
    local resposeData={code=500,msg="",desc="",server_verison=conf.version,file_orign_name={},diskstatus=disk_status}
    local file
    local file_name
    local file_name_arry = {}
    local orign_name_array ={}
    local file_cache_name=nil
    local stringy = require "stringy"
    local file_entity =nil 
    -- form 表单内数据存放位置
    local result = {
        data = {},
        indexes = {}
    }
    local part_index = 1
    local part_name, part_value


    if not form then
        resposeData.msg="文件不存在"
        resposeData.code="501"
        ngx.say(cjson.encode(resposeData))
        return
    end
    -- test code 
    -- local typ, res, err = form:read()
    -- ngx.say(cjson.encode(tkg.loadFormInput(form,"file_path")))
    -- testcode end 

    -- 拿文件数据和form表单参数
    while true do
        form:set_timeout(1000)
        local typ, res, err = form:read()
        if not typ then
            resposeData.msg="文件不存在"
            resposeData.code="502"
            ngx.say(cjson.encode(resposeData))
            return
        end        
        if typ == "header" then
            if res[1] == "Content-Disposition" then
                local filename = tkg.getFilename(res[2])
                if filename then
                    file_cache_name = filename
                end
            end
            if stringy.startswith(string.lower(res[1]), "content-disposition") then
                local parts = stringy.split(res[3], ";")
                local current_parts = stringy.split(stringy.strip(parts[2]), "=")
                if string.lower(table.remove(current_parts, 1)) == "name" then
                    local current_value = stringy.strip(table.remove(current_parts, 1))
                    part_name = string.sub(current_value, 2, string.len(current_value) - 1)
                end
            end
        end
        -- 通过将文件缓存在内存中，等到文件全部到之后写到内存 
        -- 不合理，要改掉
        if typ == "body" then
            part_value = res
            if file then 
                file:write(res)
         
            elseif file_cache_name then 
                local extension = tkg.get_extension(file_cache_name)
                if not extension then
                    resposeData.msg="无文件后缀"
                    resposeData.code="504"
                    ngx.say(cjson.encode(resposeData))
                    return 
                end
                -- 创建文件路径
                local dir = conf.fileHome..getFileSecondPath()  
                local status = os.execute('mkdir -p '..dir)
                if not status then
                    resposeData.msg="上传出错，请检查权限"
                    resposeData.code="505"
                    ngx.log(ngx.ERR,"创建文件出错")
                    ngx.say(cjson.encode(resposeData))
                    return
                end  
                -- 如果文件扩展名命中-- 使用文件原来的名字
                if tkg.in_array(extension, conf.allow_exts) then
                    local file,err=io.open(dir..file_cache_name)
                    if file == nil then 
                        file_name = dir..tkg.getFileRealName(file_cache_name)
                    else
                        -- 文件名重复处理 时间戳_文件名
                        file.close()
                        file_name = dir..os.time().."_"..tkg.getFileRealName(file_cache_name)
                    end
                else
                    local file_id = tkg.uuid2()
                    file_name = dir..file_id.."."..extension
                end
                -- 处理文件名返回处理
                file = io.open(file_name, "w+")
                if not file then
                    resposeData.msg="上传出错，请检查写入权限"
                    ngx.log(ngx.ERR,"打开文件流失败，无法写入文件流")
                    resposeData.code="506"
                    ngx.say(cjson.encode(resposeData))
                    return
                end
                file_name = string.gsub(file_name, conf.fileHome, '')
                file:write(res)
                file_cache_name = nil                
                table.insert(file_name_arry,file_name)
                table.insert(orign_name_array,file_cache_name)
            else 
            
            end 
        end
        if typ == "part_end" then
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
            if file then 
                file:close()
                file = nil 
            end 
        end
        if typ == "eof" then
            break
        end
    end
    -- 如果form 表单里面有传文件地址，进行一个文件移动；
    local filePath = getFormParams(result,"file_path")

    if filePath then
        local dir = conf.fileHome..filePath  
        local status = os.execute('mkdir -p '..dir)
        if not status then
            resposeData.msg="上传出错，请检查权限"
            resposeData.code="508"
            ngx.log(ngx.ERR,"创建文件出错")
            ngx.say(cjson.encode(resposeData))
            return
        end
        local status_mv = os.execute('mv '..conf.fileHome..file_name_arry[1]..' '..dir..'/')
        if not status_mv then 
            resposeData.msg="上传出错，请检查权限"
            resposeData.code="509"
            ngx.log(ngx.ERR,"移动文件出错")
            ngx.say(cjson.encode(resposeData))
            return
        end
        local filenameSplit = tkg.tsplit(file_name_arry[1],"/");
        local length = table.getn(filenameSplit);
        file_name_arry[1] =  filePath..filenameSplit[length]
    end 

    
    
    if file_name then 
        resposeData.code=200
        resposeData.desc=file_name_arry
        resposeData.file_orign_name=orign_name_array
        ngx.log(ngx.ERR,"上传成功~~")
        ngx.say(cjson.encode(resposeData))
    else
        resposeData.msg="文件写入失败"
        resposeData.code="507"
        ngx.say(cjson.encode(resposeData))
    end
end
uploadHandle()
