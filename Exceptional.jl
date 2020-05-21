import Base: error
global n = UInt128(0)
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
    execute_handlers(exception)
end

function process_exception(e, id)
    if isa(e, NamedBlockReturnException) && e.block_name == id
        return e.value
    end
    throw(e)
end

# assigns a unique name using a global counter to the block
# ex: fun1, fun2, fun3 ...

function block(f)
    global n = n + 1
    id = "scope-$(n)"
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
    # "scope-N" => (ExceptionType => handler_to_execute)
    # so, to extract the handlers that are applicable to "e"
    # filter second of pair = (ExceptionType => handler_to_execute)
    # filter first of pair = ExceptionType, this type should match "e"'s type
    e_handlers = Iterators.filter(handler -> isa(e, handler.second.first), available_handlers)

    # should only execute 1 handler per handler_bind form
    handler_binds_executed = []

    for handler in e_handlers
        try
            scope = handler.first
            handler_function = handler.second.second
            if scope ∉ handler_binds_executed
                push!(handler_binds_executed, scope)
                handler_function(e)
            end
        catch exc
            if isa(exc, ReturnException)
                # if the handler executed was a restart, a ReturnException
                # will be thrown, containing a return value
                return exc.value
            else
                # any other exception thrown by the handler will not be handled
                throw(exc)
            end
        end
    end

    # this will not execute if handler "handles" the problem
    # either by using a return_from to escape, or a ReturnException
    throw(e)
end

# removes handlers from global available_handlers
# removes all that are associated with "block_name"
function remove_handlers(block_name)
    filter!(handler -> handler.first != block_name, available_handlers)
end

# adds handlers to global available_handlers
# associates them with "block_name"
function add_handlers(block_name, handlers)
    # maps the block name to the handlers
    # ex: (fun1 => handler1, fun1 => handler2, fun1 => handler3)
    handler_pairs = map(handler -> (block_name => handler), handlers)
    prepend!(available_handlers, handler_pairs)
end

# maps an array of pairs to array of the right side element
function get_second_from_pairs(pairs::Array)
    map(pair -> pair.second, pairs)
end

# gets list of restarts without the scope associated
function get_restart_list()
    get_second_from_pairs(available_restarts)
end

# gets list of handlers without the scope associated
function get_handler_list()
    get_second_from_pairs(available_handlers)
end

function handler_bind(func, handlers...)
    return_value = nothing

    block() do scope
        try
            add_handlers(scope, handlers)
            return_value = func()
        finally
            remove_handlers(scope)
        end
    end

    return_value
end

# same as remove_handlers but for restarts
function remove_restarts(block_name)
    filter!(restart -> restart.first != block_name, available_restarts)
end

# same as add_handlers but for restarts
function add_restarts(block_name, restarts)
    # maps the block name to the restarts
    # ex: (fun1 => restart1, fun1 => restart2, fun1 => restart3)
    restart_pairs = map(restart -> (block_name => restart), restarts)
    prepend!(available_restarts, restart_pairs)
end

function restart_bind(func, restarts...)

    return_value = nothing

    block() do scope
        try
            add_restarts(scope, restarts)
            return_value = func()
        finally
            remove_restarts(scope)
        end
    end

    return_value
end

function invoke_restart(name, args...)
    println("invoking restart $(name) $(args)")

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
            return true
        end
    end
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
