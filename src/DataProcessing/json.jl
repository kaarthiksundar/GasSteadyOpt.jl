"Grab data from json file inside zip" 
function _parse_json_file_from_zip(zip_reader, path_index)
    json_str = ZipFile.read(zip_reader.files[path_index], String)
    return JSON.parse(json_str, dicttype=Dict)
end

"Grab the data from a json field"
function _parse_json(file_string::AbstractString)
    (~isfile(file_string)) && (return Dict{String,Any}())
    data = open(file_string, "r") do io
        _parse_json(io)
    end
    return data
end

""
function _parse_json(io::IO)
    data = JSON.parse(io, dicttype=Dict)
    return data
end