function read_nomination_cases(file::AbstractString)::NamedTuple
    data = DataProcessing._parse_json(file)
    num_cases = (data |> last)["files"]
    cases = map(x -> split(x["name"], ".")[1], (data |> first)["contents"])
    return (cases = cases, num_cases = num_cases)
end 