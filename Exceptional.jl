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
    return_value = nothing
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
function execute_handlers(e::Exception)

    if isa(e, NamedBlockReturnException) || isa(e, ReturnException)
        throw(e)
    end

    handler_list = get_handler_list()

    # filters handlers that are applicable to the exception
    filtered = Iterators.filter(handler -> isa(e, handler.first), handler_list)
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
                #println("[execute_handlers] Unexpected exception $(exc)")
                throw(exc)
            end
        end
    end

    # this will not execute if handler "handles" the problem
    # (by throwing an appropriate exception)
    throw(e)
end

function remove_handlers(block_name)
    filter!(handler -> handler.first != block_name, available_handlers)
end

function add_handlers(block_name, handlers)
    handler_pairs = map(handler -> (block_name => handler), handlers)
    append!(available_handlers, handler_pairs)
end

function get_second_from_pairs(pairs::Array)
    map(pair -> pair.second, pairs)
end

function get_restart_list()
    get_second_from_pairs(available_restarts)
end

function get_handler_list()
    get_second_from_pairs(available_handlers)
end

function handler_bind(func, handlers...)

    return_value = nothing
    block() do scope
        add_handlers(scope, handlers)
        try
            return_value = func()
        catch e
            try
                return_value = execute_handlers(e)
            catch inner_exc
                remove_handlers(scope)
                throw(inner_exc)
            end
        end
        remove_handlers(scope)
    end
    return_value
end

function remove_restarts(block_name)
    filter!(restart -> restart.first != block_name, available_restarts)
end

function add_restarts(block_name, restarts)
    # maps the block name to the restarts
    # ex: (fun1 => restart1, fun1 => restart2..)
    restart_pairs = map(restart -> (block_name => restart), restarts)
    append!(available_restarts, restart_pairs)
end

function restart_bind(func, restarts...)

    MAX_TRIES = 5
    tries = 0
    return_value = nothing

    block() do scope
        global available_restarts
        add_restarts(scope, restarts)
        while true
            try
                return_value = func()
                break
            catch e
                tries += 1
                if tries == MAX_TRIES
                    remove_restarts(scope)
                    throw(e)
                else
                    try
                        return_value = execute_handlers(e)
                    catch inner_exc
                        remove_restarts(scope)
                        throw(inner_exc)
                    end
                    break
                end
            end
        end
        remove_restarts(scope)
        return return_value
    end
end

function invoke_restart(name, args...)
    println("invoking restart $(name) $(args)")
    global available_restarts

    restart_list = get_restart_list()

    size = length(restart_list)
    for i = 1:size
        if restart_list[i].first == name
            if length(args) == 1
                restart_return(restart_list[i].second(args[1]))
            elseif length(args) > 1
                restart_return(restart_list[i].second(args))
            else
                restart_return(restart_list[i].second())
            end
        end
    end
end

function available_restart(name)
    global available_restarts

    restart_list = get_restart_list()

    size = length(restart_list)
    for i = 1:size
        if restart_list[i].first == name
            println("restart $(name) is available")
            return true
        end
    end
    println("restart $(name) is not available")
    false
end

function reciprocal(x)
    if x == 0
        error(DivisionByZero())
    else
        1 / x
    end
end

reciprocal2(value) = restart_bind(:return_zero => ()->0, :return_value => identity,:retry_using => reciprocal) do
    reciprocal(0)
end

infinity() = restart_bind(:just_do_it => ()->1/0) do
    reciprocal2(0)
end
