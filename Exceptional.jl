import Base: error
global n = 0

# Sent by return_from
# contains the block_name to return from and the return value

struct ReturnValueException <: Exception
    block_name::String
    value::Any
end

struct DivisionByZero <: Exception end

# throws a ReturnValueException with the given block name and return value

function return_from(name, value = nothing)
    throw(ReturnValueException(name, value))
end

function error(exception::Exception)
    println("ERROR: $(exception) was not handled")
    throw(exception)
end


function process_exception(e, id)
    if isa(e, ReturnValueException)
        if e.block_name == id
            println("return_from sent to me ($(id)), returning value ($(e.value))")
            return e.value
        else
            println("return_from sent to '$(e.block_name)', I am '$(id)', propagating")
            throw(e)
        end
    else
         println("Unexpected exception caught: $(e), re-throwing")
         throw(e)
    end
end

# assigns a unique name using a global counter to the block
# ex: fun1, fun2, fun3 ...

function block(f)
    global n = n + 1
    id = "fun$(n)"
    return_value = ""
    try
        println("executing named block '$(id)'")
        return_value = f(id)
        println("clean finish on named block '$(id)'")
    catch e
        return_value = process_exception(e, id)
        println("return_from used on named block '$(id)'")
    end
    return_value
end

function handler_bind(f, aiai...)
    try
        f()
    catch e
        for func in aiai
            if isa(e, func.first)
                func.second(1)
            end
        end
    end
end

mystery(n) =
    1 +
    block() do outer
        1 +
        block() do inner
            1 +
            if n == 0
                return_from(inner,1)
            elseif n == 1
                return_from(outer, 1)
            else
                1
        end
    end
end

function reciprocal(x)
    if x == 0
        error(DivisionByZero())
    else
        1/x
    end
end

mystery(0)

println()

mystery(1)

println()

mystery(2)

println()
