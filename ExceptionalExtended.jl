include("Exceptional.jl")

function signal(e::Exception)
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
end

function error(exception::Exception)
    val = signal(exception)
    if isnothing(val)
        if size(available_restarts, 1) > 0
            ask_for_help()
        else
            throw(exception)
        end
    end
    val
end

struct Restart
    name
    desc::String
    func::Function
end

(restart::Restart)(args...) = restart.func(args...)

function print_available_restarts()
    println("Restarts: ")
    restarts = get_restart_list()
    for (index, restart) in enumerate(restarts)
        println(" $(index): [$(restart.name)] $(restart.desc)")
    end
end

function ask_for_help()
    print_available_restarts()
    restart_selected = readline()
    println("you selected $(restart_selected)")

    try
        int_restart = parse(Int64, restart_selected)
        restart = get_restart_list()[int_restart]
        println(restart)
    catch e
        println(e)
    end

end

restart_bind(
    Restart(:MAGIC, "Does magic", () -> "magic"),
    Restart(:NOTMAGIC, "does not do magic", () -> "")
) do
    error(DivisionByZero())
end
