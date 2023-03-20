function write_csv(file, header, rows)
    open(file, "w") do io
        writedlm(io, [permutedims(header); reduce(hcat, rows)'], ',')
    end
end