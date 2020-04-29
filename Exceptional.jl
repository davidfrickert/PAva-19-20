import Base: error
global n = 0
global saved =0

# Used by restarts

struct ReturnException <: Exception
    value::Any
end

# Sent by return_from
# contains the block_name to return from and the return value

struct NamedBlockReturnException <: Exception
    block_name::String
    value::Any
end

struct DivisionByZero <: Exception end

# throws a NamedBlockReturnException with the given block name and return value

function return_from(name, value = nothing)
    throw(NamedBlockReturnException(name, value))
end

# not in original specificatin
# similar to return_from but no named blocks
function restart_return(value = nothing)
    throw(ReturnException(value))
end

function error(exception::Exception)
    throw(exception)
end

function process_exception(e, id)
    if isa(e, NamedBlockReturnException)
        if e.block_name == id
            return e.value
        else
            throw(e)
        end
    else
        #println("Unexpected exception caught: $(e), re-throwing")
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
        return_value = f(id)
    catch e
        return_value = process_exception(e, id)
    end
    return_value
end

## executes handlers applicable to Exception e
# handlers: (Exception1 => f1, Exception2 => f2, ...)
##
function execute_handlers(handlers, e::Exception)

    if isa(e, NamedBlockReturnException) || isa(e, ReturnException)
        throw(e)
    end

    # filters handlers that are applicable to the exception
    filtered = Iterators.filter(handler -> isa(e, handler.first), handlers)

    for handler in filtered
        try
            # execute handler function
            handler.second(1)
            # this will not execute if handler "handles" the problem
            # (by throwing an appropriate exception)
            throw(e)
        catch exc
            # if the handler executed was a restart
            # it will send a ReturnException to deliver the value
            if isa(exc, ReturnException)
                return exc.value
            else
                println("[execute_handlers] Unexpected exception $(exc)")
                throw(exc)
            end
        end
    end
end

function handler_bind(func, handlers...)
    try
        func()
    catch e
        #println("[handler_bind] catching $(e)")
        execute_handlers(handlers, e)
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
#    println("invoking restart $(name) $(args)")
    global saved
    size = length(saved)
    for i = 1:size
        if saved[i].first == name
            if length(args) == 1
                restart_return(saved[i].second(args[1]))
            elseif length(args) > 1
                restart_return(saved[i].second(args))
            else
                restart_return(saved[i].second())
            end
        end
    end
end

function available_restart(name)
    global saved
    size = length(saved)
    for i = 1:size
        if saved[i].first == name
            return true
        end
    end
    false
end

reciprocal2(value) = restart_bind(:return_zero => ()->0, :return_value => identity,:retry_using => reciprocal) do
    value == 0 ?
    error(DivisionByZero()) :
    1/value
end

infinity() = restart_bind(:just_do_it => ()->1/0) do
    reciprocal(0)
end


handler_bind(DivisionByZero =>
            (c)->invoke_restart(:return_zero)) do
            reciprocal2(0)
end

handler_bind(DivisionByZero =>
            (c)->invoke_restart(:just_do_it))
            infinity()
end
