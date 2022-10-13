
## Generate save name from parameters ##
function get_savename(basename; parameters=Dict([]), kwargs...)

    # Merge parameters with keyword arguments
    parameters = merge(
        deepcopy(parameters), 
        Dict([(String(key), val) for (key, val) in kwargs])
    )

    # Greate suffix from parameters
    suffix = ""
    for (key, val) in sort(collect(parameters), by=q->q[1])
        (val === nothing) || (val == false) ? continue : nothing
        key_str = replace(key,"_"=>"")
        if isa(val, String)
            val_str = val
        else
            val_str = join(val,"X")
        end
        suffix = "$(suffix)_$(key_str)=$(val_str)"
    end

    # Add suffix to name
    name = basename
    if length(suffix) > 0
        name = name * suffix
    end

    # Return name
    return name
end

## Define save function ##
function precomputed_save(self, matrix, matrixname; parameters=Dict([]), kwargs...)
            
    # Get atributes
    name = self.name
    path = self.path
    verbose = self.verbose

    # Set up savename
    matrixname = get_savename(matrixname; parameters=parameters, kwargs...)

    # Check if directory exists
    if !(name in readdir(path))
        mkdir("$(path)$(name)")
        verbose ? println("Created directory: $(path)$(name)") : nothing
    end

    # Save matrix
    fid = h5open("$(path)$(name)/$(matrixname).h5", "w")
    fid["type"] = string(typeof(matrix))
    if issparse(matrix)
        # If matrix is sparse then save as sparse matrix
        if ndims(matrix) == 1
            rows, vals = findnz(sparsevec(matrix))
            nrows = length(matrix)
            fid["rows"] = rows
            fid["vals"] = vals
            fid["nrows"] = nrows
        else
            rows, cols, vals = findnz(sparse(matrix))
            nrows, ncols = size(matrix)
            fid["rows"] = rows
            fid["cols"] = cols
            fid["vals"] = vals
            fid["nrows"] = nrows
            fid["ncols"] = ncols
        end
    else
        # If matrix is dense then save as dense matrix
        fid["matrix"] = matrix
    end
    close(fid)
    verbose ? println("Saved precomputed matrix: $(matrixname) for $(name)") : nothing

    # return nothing
    return nothing
end

## Define load function ##
function precomputed_load(self, matrixname; parameters=Dict([]), kwargs...)
    
    # Get attributes
    path = self.path
    name = self.name
    verbose = self.verbose

    # Set up savename
    matrixname = get_savename(matrixname; parameters=parameters, kwargs...)
    
    # Check if matrix is in path
    if !(self.check_existence(matrixname))
        verbose ? println("Could not find precomputed matrix: $(matrixname) from $(name)") : nothing
        return nothing
    end
    # matrix = nothing
    # if in(name, readdir(path))
    #     if in(matrixname*".h5", readdir("$(path)$(name)"))
    #         @goto found_matrix
    #     end
    # end
    # verbose ? println("Could not find precomputed matrix: $(matrixname) from $(name)") : nothing
    # return nothing
    # @label found_matrix

    # Load matrix
    fid = h5open("$(path)$(name)/$(matrixname).h5", "r")
    type = read(fid["type"])
    if occursin("sparse", lowercase(type))
        # If matrix is sparse then load as sparse matrix
        if occursin("vector", lowercase(type))
            rows = read(fid["rows"])
            vals = read(fid["vals"])
            nrows = read(fid["nrows"])
            matrix = sparsevec(rows, vals, nrows)
        else
            rows = read(fid["rows"])
            cols = read(fid["cols"])
            vals = read(fid["vals"])
            nrows = read(fid["nrows"])
            ncols = read(fid["ncols"])
            # matrix = sparse(rows, cols, vals, nrows, ncols)
            matrix = sparse(cols, rows, vals, ncols, nrows)'  # Load as CSR matrix
        end
    else
        # If matrix is dense then load as dense matrix
        matrix = read(fid["matrix"])
    end
    close(fid)
    verbose ? println("Loaded precomputed matrix: $(matrixname) from $(name)") : nothing

    # Return matrix
    return matrix
end

## Define check function ##
function precomputed_check_existence(self, matrixname; parameters=Dict([]), kwargs...)
    
    # Get attributes
    path = self.path
    name = self.name
    verbose = self.verbose

    # Set up savename
    matrixname = get_savename(matrixname; parameters=parameters, kwargs...)
    
    # Check if matrix is in path
    if in(name, readdir(path))
        if in(matrixname*".h5", readdir("$(path)$(name)"))
            return true
        end
    end
    return false
end

### Precomputed ###
mutable struct PrecomputedCache
    name::String
    path::String
    save::Function
    load::Function
    verbose::Bool
    function PrecomputedCache(name; path=nothing, verbose=false, parameters=Dict([]), kwargs...)

        # Set up name
        name = get_savename(name; parameters=parameters, kwargs...)

        # Set up path
        if path === nothing
            if "PATHTOPRECOMPUTED" in keys(ENV)
                path = ENV["PATHTOPRECOMPUTED"]
            else
                path = "./"
            end
        end
        if path[end] != '/'
            path = path * "/"
        end

        # Create self reference
        self = new()

        # Set attributes
        self.name = name
        self.path = path
        self.verbose = verbose
        self.save = function (matrix, matrixname; parameters=Dict([]), kwargs...)
            precomputed_save(self, matrix, matrixname; parameters=parameters, kwargs...)
        end
        self.load = function (matrixname; parameters=Dict([]), kwargs...)
            precomputed_load(self, matrixname; parameters=parameters, kwargs...)
        end
        self.check_existence = function (matrixname; parameters=Dict([]), kwargs...)
            precomputed_check_existence(self, matrixname; parameters=parameters, kwargs...)
        end

        return self
    end
end

