using Test

# Tests / Examples

include("Exceptional.jl")

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

@testset "mystery" begin
    @test mystery(0) == 3
    @test mystery(1) == 2
    @test mystery(2) == 4
end

struct DivisionByZero <: Exception end

println()

try
    handler_bind(DivisionByZero => (c) -> println("I saw a division by zero")) do
        reciprocal(0)
    end
catch e
    print("ERROR: $(e) was not handled.")
end

println()

handler_bind_example = block() do escape
    handler_bind(DivisionByZero => (c) -> (
        println("I saw it too");
        return_from(escape, "Done"))
    ) do
        handler_bind(
            DivisionByZero => (c) -> println("I saw a division by zero"),
        ) do
            reciprocal(0)
        end
    end
end
print(handler_bind_example)

# not working as intended
handler_bind_example2 = block() do escape
    handler_bind(DivisionByZero =>
        (c)-> println("I saw it too")) do
        handler_bind(DivisionByZero =>
        (c)->(println("I saw a division by zero");
            return_from(escape, "Done"))) do
            reciprocal(0)
        end
    end
end

print(handler_bind_example2)

println()

## using for

handler_bind(DivisionByZero =>
    (c)->
   for restart in (:return_one, :return_zero, :die_horribly)
                if available_restart(restart)
                   invoke_restart(restart)
             end
           end
    ) do
    restart_bind(:return_one => ()->1, :return_value => identity,
        :retry_using => reciprocal) do
        reciprocal(0)
    end
end

println()

## infinity

handler_bind(DivisionByZero =>
    (c)->invoke_restart(:return_zero)) do
    infinity()
end
# 0

handler_bind(DivisionByZero =>
    (c)->invoke_restart(:return_value, 1)) do
    infinity()
end
# 1

handler_bind(DivisionByZero =>
    (c)->invoke_restart(:retry_using, 10)) do
    infinity()
end
# 0.1
handler_bind(DivisionByZero =>
    (c)->invoke_restart(:just_do_it)) do
    infinity()
end
#Inf
