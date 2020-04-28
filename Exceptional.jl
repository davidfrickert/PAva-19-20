import Base: error
global n = 0
global saved =0

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
    throw(exception)
end


function process_exception(e, id)
    if isa(e, ReturnValueException)
        if e.block_name == id
            #println("return_from sent to me ($(id)), returning value ($(e.value))")
            return e.value
        else
            #println("return_from sent to '$(e.block_name)', I am '$(id)', propagating")
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
        #println("executing named block '$(id)'")
        return_value = f(id)
        #println("clean finish on named block '$(id)'")
    catch e
        return_value = process_exception(e, id)
        #println("return_from used on named block '$(id)'")
    end
    return_value
end

function handler_bind(func, handlers...)
    try
        func()
    catch e
        for handle in handlers
            if isa(e, handle.first)
                handle.second(1)
                throw(e)
            end
        end
    end
end

function reciprocal(x)
    if x == 0
        error(DivisionByZero())
    else
        1 / x
    end
end

function restart_bind(func, restarts...)
    global saved
    saved = restarts
        func()
end

function invoke_restart(name, args...)
    global saved
    size = length(saved)
    for i = 1:size
        if saved[i].first == name
            if length(args) > 0
                return saved[i].second(args)
            else
                return saved[i].second()
            end
        end
    end
end


reciprocal2(value) = restart_bind(:return_zero => ()->0, :return_value => identity,:retry_using => reciprocal) do
    value == 0 ?
    error(DivisionByZero()) :
    1/value
end
