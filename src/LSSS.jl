
function Large_Scale_Simulation_Study(folder, name, parameters, model)
    if !isdir(folder * "/" * name)
        mkdir(folder * "/" * name)
    end
    Threads.@threads for i in eachindex(parameters)
        p = parameters[i]
        try
            results = model(p)
            to_save = (parameters = p, results = results)
            idd = rand(1:1000000000000000000)
            path = folder * "/" * name * "/" * string(idd) * ".jld2"
            save(path, Dict("results" => to_save))
        catch e
            println(e)
        end
    end
end

function Load_Simulation(path)
    files = readdir(path, join=true)
    results = Vector{}(undef, length(files))
    for (i, f) in enumerate(files)
        results[i] = load(f)["results"]
    end
    return results
end

function Query_Simulation(results, query_obj)
    valid = Vector{Any}()
    for r in results
        pars = r.parameters
        vv = true
        for (key, val) in zip(keys(query_obj), query_obj)
            if !(pars[key] in val)
                vv = false
            end
        end
        if vv
            valid = [valid; r]
        end
    end
    return valid
end

function results_summary(results, keys, stat_, n)
    D = DataFrame(results_summary_recursion(results, keys,  Dict(), stat_, keys, n), :auto)
    rename!(D, [names(D)[i] => string(keys[i]) for i in 1:length(keys)])
    return D
end


function results_summary_recursion(results, keys, query_obj, stat_, all_keys, n)
    n_k = length(all_keys) + n
    next_key = keys[1]
    all_comb = unique([r.parameters[next_key] for r in results])
    od = sortperm([values(g) for g in all_comb])
    all_comb = all_comb[od]
    mat = reshape(zeros(n_k), 1, n_k)
    for vv in all_comb
        query_obj[next_key] = vv
        if length(keys) == 1
            tp = (; query_obj...)
            q = Query_Simulation(results, tp)
            st = stat_(q)
            mat = vcat(mat, reshape([[query_obj[k] for k in all_keys]; st], 1, n_k))
        else
            mat = vcat(mat,results_summary_recursion(results, keys[2:end], query_obj, stat_, all_keys, n))
        end
    end
    return mat[2:end, :]
end


function table_recursion(results, keys, query_obj, stat_)
    if length(keys) != 2
        next_key = keys[1]
        all_comb = unique([r.parameters[next_key] for r in results])
        od = sortperm([values(g) for g in all_comb])
        all_comb = all_comb[od]

        tables = Vector{}()
        for vv in all_comb
            query_obj[next_key] = vv
            tables = [tables; (string(next_key) * "=" * string(vv)) => table_recursion(results, keys[2:end], query_obj, stat_)]
        end
        return join_table(tables...)
    else
        next_key = keys[1]
        base_key = keys[2]
        all_comb = unique([r.parameters[next_key] for r in results])
        od = sortperm([values(g) for g in all_comb])
        all_comb = all_comb[od]

        all_comb_base = unique([r.parameters[base_key] for r in results])
        od = sortperm([values(g) for g in all_comb_base])
        all_comb_base = all_comb_base[od]

        tables = nothing
        for vv in all_comb
            query_obj[next_key] = vv
            x = Vector{Any}()
            y = Vector{Any}()
            for vv_base in all_comb_base
                query_obj[base_key] = vv_base
                tp = (; query_obj...)
                q = Query_Simulation(results, tp)
                st = stat_(q)
                x = [x; string(base_key) * "=" * string(vv_base)]
                y = [y; st]
            end
            if isnothing(tables)
                tables = TableCol(string(next_key) * "=" * string(vv), x, y)
            else
                tables = hcat(tables, TableCol(string(next_key) * "=" * string(vv), x, y))
            end
        end
        return tables
    end
end

function Simulation_Table(results, keys, stat_)
    table_recursion(results, reverse(keys), Dict(), stat_)
end

