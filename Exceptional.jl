import Base: error
global n = 0
global available_restarts = []
global available_handlers = []
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

    # this will not execute if handler "handles" the problem
    # (by throwing an appropriate exception)
    throw(e)
end

function execute_handlers(e::Exception)
    execute_handlers(available_handlers, e)
end

function remove_handlers(handlers)
    filter!(handler -> handler ∉ handlers, available_handlers)
end

function handler_bind(func, handlers...)
    append!(available_handlers, handlers)
    return_value = nothing
    try
        return_value = func()
    catch e
        try
            return_value = execute_handlers(handlers, e)
        catch inner_exc
            remove_handlers(handlers)
            throw(inner_exc)
        end
    end
    remove_handlers(handlers)
    return_value
end

function reciprocal(x)
    if x == 0
        error(DivisionByZero())
    else
        1 / x
    end
end

function remove_restarts(restarts)
    # filter macro modifies the array, ∉ = not in
    filter!(restart -> restart ∉ restarts, available_restarts)
end

function restart_bind(func, restarts...)
    global available_restarts
    append!(available_restarts, restarts)
    MAX_TRIES = 5
    tries = 0
    return_value = nothing
    while true
        try
            return_value = func()
            break
        catch e
            tries += 1
            if tries == MAX_TRIES
                remove_restarts(restarts)
                throw(e)
            else
                try
                    return_value = execute_handlers(e)
                catch inner_exc
                    remove_restarts(restarts)
                    throw(inner_exc)
                end
                break
            end
        end
    end
    remove_restarts(restarts)
    return return_value
end

function invoke_restart(name, args...)
    println("invoking restart $(name) $(args)")
    global available_restarts
    size = length(available_restarts)
    for i = 1:size
        if available_restarts[i].first == name
            if length(args) == 1
                restart_return(available_restarts[i].second(args[1]))
            elseif length(args) > 1
                restart_return(available_restarts[i].second(args))
            else
                restart_return(available_restarts[i].second())
            end
        end
    end
end

function available_restart(name)
    global available_restarts
    size = length(available_restarts)
    for i = 1:size
        if available_restarts[i].first == name
            println("restart $(name) is available")
            return true
        end
    end
    println("restart $(name) is not available")
    false
end

reciprocal2(value) = restart_bind(:return_zero => ()->0, :return_value => identity,:retry_using => reciprocal) do
    reciprocal(0)
end

infinity() = restart_bind(:just_do_it => ()->1/0) do
    reciprocal2(0)
end
