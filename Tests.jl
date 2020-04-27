using Test

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

@testset "mystery(0)" begin
    @test mystery(0) == 3
end

@testset "mystery(1)" begin
    @test mystery(1) == 2
end

@testset "mystery(2)" begin
    @test mystery(2) == 4
end
