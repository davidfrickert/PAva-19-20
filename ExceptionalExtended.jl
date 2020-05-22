include("Exceptional.jl")

function signal(e::Exception)
    if isa(e, NamedBlockReturnException) || isa(e, ReturnException)
        throw(e)
    end

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
                return exc.value
            else
                throw(exc)
            end
        end
    end
end

function error(exception::Exception)
    val = signal(exception)
    # if no handler available for this exception and there are available restarts
    # ask user for help
    if isnothing(val)
        if length(available_restarts) > 0
            val = ask_for_help()
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
        return restart()
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
