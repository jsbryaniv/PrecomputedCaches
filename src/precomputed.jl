
## Define save function ##
function precomputed_save(self, matrix, matrixname)
            
    # Get atributes
    name = self.name
    path = self.path
    verbose = self.verbose

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
        rows, cols, vals = findnz(sparse(matrix))
        nrows, ncols = size(matrix)
        fid["rows"] = rows
        fid["cols"] = cols
        fid["vals"] = vals
        fid["nrows"] = nrows
        fid["ncols"] = ncols
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
function precomputed_load(self, matrixname)
    
    # Get attributes
    path = self.path
    name = self.name
    verbose = self.verbose
    
    # Check if matrix is in path
    matrix = nothing
    if in(name, readdir(path))
        if in(matrixname*".h5", readdir("$(path)$(name)"))
            @goto found_matrix
        end
    end
    verbose ? println("Could not find precomputed matrix: $(matrixname) from $(name)") : nothing
    return nothing
    @label found_matrix

    # Load matrix
    fid = h5open("$(path)$(name)/$(matrixname).h5", "r")
    type = read(fid["type"])
    if occursin("sparse", lowercase(type))
        # If matrix is sparse then load as sparse matrix
        rows = read(fid["rows"])
        cols = read(fid["cols"])
        vals = read(fid["vals"])
        nrows = read(fid["nrows"])
        ncols = read(fid["ncols"])
        # matrix = sparse(rows, cols, vals, nrows, ncols)
        matrix = sparse(cols, rows, vals, ncols, nrows)'  # Load as CSR matrix
    else
        # If matrix is dense then load as dense matrix
        matrix = read(fid["matrix"])
    end
    close(fid)
    verbose ? println("Loaded precomputed matrix: $(matrixname) from $(name)") : nothing

    # Return matrix
    return matrix
end


### Precomputed ###
mutable struct Precomputed
    name::String
    path::String
    save::Function
    load::Function
    verbose::Bool
    function Precomputed(name, parameters=nothing; path=nothing, verbose=false)

        # Set up name
        if parameters !== nothing
            suffix = ""
            for (key, val) in sort(collect(parameters), by=q->q[1])
                (val === nothing) || (val == false) ? continue : nothing
                suffix = "$(suffix)_$(replace(key,"_"=>""))=$(join(val,"X"))"
            end
            name = name * suffix
        end

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
        self.save = function (matrix, matrixname)
            precomputed_save(self, matrix, matrixname)
        end
        self.load = function (matrixname)
            precomputed_load(self, matrixname)
        end

        return self
    end
end

