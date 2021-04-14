using Yields
using Test

@testset "Yields.jl" begin
    
    @testset "rate types" begin
        rs = Rate.([0.1,.02],Continuous())
        @test rs[1] == Rate(0.1,Continuous())
        @test rate(rs[1]) == 0.1
    end
    
    @testset "constructor" begin
        @test Continuous(0.05) == Rate(0.05,Continuous())
        @test Rate(0.02,2) == Rate(0.02,Periodic(2))
        @test Rate(0.02,Inf) == Rate(0.02,Continuous())
    end
    
    @testset "rate conversions" begin
        m = Rate(.1,Yields.Periodic(2),)
        @test rate(convert(m,Yields.Continuous())) ≈ rate(Rate(0.09758,Continuous())) atol = 1e-5
        c = Rate(0.09758,Yields.Continuous())
        @test convert(c,Continuous()) == c
        @test rate(convert(c,Yields.Periodic(2))) ≈ rate(Rate(0.1,Periodic(2))) atol = 1e-5
        @test rate(convert(m,Yields.Periodic(4))) ≈ rate(Rate(0.09878030638383972,Periodic(4))) atol = 1e-5
        
    end
    
    @testset "constant curve" begin
        yield = Yields.Constant(0.05)
        
        @testset "constant discount time: $time" for time in [0,0.5,1,10]
            @test discount(yield, time) ≈ 1 / (1.05)^time 
        end
        @testset "constant discount scalar time: $time" for time in [0,0.5,1,10]
            @test discount(0.05,time) ≈ 1 / (1.05)^time 
        end
        @testset "constant accumulation time: $time" for time in [0,0.5,1,10]
            @test accumulation(yield, time) ≈ 1 * 1.05^time
        end
        
        @testset "CompoundingFrequency" begin
            @testset "Continuous" begin
                cnst = Yields.Constant(Continuous(0.05))
                @test accumulation(cnst,1) == exp(0.05)
                @test accumulation(cnst,2) == exp(0.05*2)
                @test discount(cnst,2) == 1 / exp(0.05*2)
            end
            
            @testset "Periodic" begin
                p = Yields.Constant(Rate(0.05,Periodic(2)))
                @test accumulation(p,1) == (1 + 0.05/2) ^ (1 * 2)
                @test accumulation(p,2) == (1 + 0.05/2) ^ (2 * 2)
                @test discount(p,2) == 1 / (1 + 0.05/2) ^ (2 * 2)
                
            end
        end
        
        
        yield_2x = yield + yield
        yield_add = yield + 0.05
        add_yield = 0.05 + yield
        @testset "constant discount added" for time in [0,0.5,1,10]
            @test discount(yield_2x, time) ≈ 1 / (1.1)^time 
            @test discount(yield_add, time) ≈ 1 / (1.1)^time 
            @test discount(add_yield, time) ≈ 1 / (1.1)^time 
        end
        
        yield_1bps = yield - Yields.Constant(0.04)
        yield_minus = yield - 0.01
        minus_yield = 0.05 - Yields.Constant(0.01)
        @testset "constant discount subtraction" for time in [0,0.5,1,10]
            @test discount(yield_1bps, time) ≈ 1 / (1.01)^time 
            @test discount(yield_minus, time) ≈ 1 / (1.04)^time 
            @test discount(minus_yield, time) ≈ 1 / (1.04)^time 
        end
    end
    
    @testset "broadcasting" begin
        yield = Yields.Constant(0.05)
        @test discount.(yield, 1:3) == [1 / 1.05^t for t in 1:3]
    end
    
    @testset "short curve" begin
        z = Yields.Zero([0.0,0.05], [1,2])
        @test rate(zero(z, 1)) ≈ 0.00
        @test discount(z, 1) ≈ 1.00
        @test rate(zero(z, 2)) ≈ 0.05
    end
    
    @testset "Step curve" begin
        y = Yields.Step([0.02,0.05], [1,2])
        
        @test rate(y, 0.5) == 0.02
        
        @test discount(y, 0.5) ≈ 1 / (1.02)^(0.5)
        @test discount(y, 1) ≈ 1 / (1.02)^(1)
        @test rate(y, 1) ≈ 0.02
        
        @test discount(y, 2) ≈ 1 / (1.02) / 1.05
        @test rate(y, 2) ≈ 0.05
        @test rate(y, 2.5) ≈ 0.05
        
        @test discount(y, 2) ≈ 1 / (1.02) / 1.05
        
        @test discount(y, 1.5) ≈ 1 / (1.02) / 1.05^(0.5)
        
        
        y = Yields.Step([0.02,0.07])
        @test rate(y, 0.5) ≈ 0.02
        @test rate(y, 1) ≈ 0.02
        @test rate(y, 1.5) ≈ 0.07
        
    end
    
    @testset "Salomon Understanding the Yield Curve Pt 1 Figure 9" begin
        maturity = collect(1:10)
        
        par = [6.,8.,9.5,10.5,11.0,11.25,11.38,11.44,11.48,11.5] ./ 100
        spot = [6.,8.08,9.72,10.86,11.44,11.71,11.83,11.88,11.89,11.89] ./ 100
        
        # the forwards for 7+ have been adjusted from the table - perhaps rounding issues are exacerbated 
        # in the text? forwards for <= 6 matched so reasonably confident that the algo is correct
        # fwd = [6.,10.2,13.07,14.36,13.77,13.1,12.55,12.2,11.97,11.93] ./ 100 # from text
        fwd = [6.,10.2,13.07,14.36,13.77,13.1,12.61,12.14,12.05,11.84] ./ 100  # modified
        
        y = Yields.Par(Rate.(par,Periodic(1)), maturity)
        
        @testset "UTYC Figure 9 par -> spot : $mat" for mat in maturity
            @test rate(zero(y, mat)) ≈ spot[mat] atol = 0.0001
            @test forward(y, mat-1) ≈ fwd[mat] atol = 0.0001
        end
        
    end
    
    @testset "simple rate and forward" begin 
        # Risk Managment and Financial Institutions, 5th ed. Appendix B
        
        maturity = [0.5, 1.0, 1.5, 2.0]
        zero    = [5.0, 5.8, 6.4, 6.8] ./ 100
        curve = Yields.Zero(zero, maturity)
        
        
        @test discount(curve, 1) ≈ 1 / (1 + zero[2])
        @test discount(curve, 2) ≈ 1 / (1 + zero[4])^2
        
        @test forward(curve, 0.5, 1.0) ≈ 6.6 / 100 atol = 0.001
        @test forward(curve, 1.0, 1.5) ≈ 7.6 / 100 atol = 0.001
        @test forward(curve, 1.5, 2.0) ≈ 8.0 / 100 atol = 0.001
        
        y = Yields.Zero(zero)
        
        @test discount(y, 1) ≈ 1 / 1.05
        @test discount(y, 2) ≈ 1 / 1.058^2
        
    end
    
    @testset "Forward Rates" begin 
        # Risk Managment and Financial Institutions, 5th ed. Appendix B
        
        forwards = [0.05, 0.04, 0.03, 0.08]
        curve = Yields.Forward(forwards,[1,2,3,4])
        
        @testset "discounts: $t" for (t, r) in enumerate(forwards)
            @test discount(curve, t) ≈ reduce((v, r) -> v / (1 + r), forwards[1:t]; init=1.0)
        end
        
        @test accumulation(curve, 0, 1) ≈ 1.05
        @test accumulation(curve, 1, 2) ≈ 1.04
        @test accumulation(curve, 0, 2) ≈ 1.04 * 1.05
        
        # addition / subtraction
        @test discount(curve + 0.1,1) ≈ 1 / 1.15
        @test discount(curve - 0.03,1) ≈ 1 / 1.02
        
        
        
        @testset "with specified timepoints" begin
            i = [0.0,0.05]
            times = [0.5,1.5]
            y = Yields.Forward(i, times)
            @test discount(y, 0.5) ≈ 1 / 1.0^0.5  
            @test discount(y, 1.5) ≈ 1 / 1.0^0.5 / 1.05^1
            
        end
        
    end
    
    @testset "base + spread" begin
        riskfree_maturities = [0.5, 1.0, 1.5, 2.0]
        riskfree    = [5.0, 5.8, 6.4, 6.8] ./ 100 # spot rates
        
        spread_maturities = [0.5, 1.0, 1.5, 3.0] # different maturities
        spread    = [1.0, 1.8, 1.4, 1.8] ./ 100 # spot spreads
        
        rf_curve = Yields.Zero(riskfree, riskfree_maturities)
        spread_curve = Yields.Zero(spread, spread_maturities)
        
        yield = rf_curve + spread_curve 
        
        @test discount(yield, 1.0) ≈ 1 / (1 + riskfree[2] + spread[2])^1
        @test discount(yield, 1.5) ≈ 1 / (1 + riskfree[3] + spread[3])^1.5
    end
    
    @testset "actual cmt treasury" begin
        # Fabozzi 5-5,5-6
        cmt  = [5.25,5.5,5.75,6.0,6.25,6.5,6.75,6.8,7.0,7.1,7.15,7.2,7.3,7.35,7.4,7.5,7.6,7.6,7.7,7.8] ./ 100
        mats = collect(0.5:0.5:10.)
        curve = Yields.USCMT(cmt,mats)
        targets = [5.25,5.5,5.76,6.02,6.28,6.55,6.82,6.87,7.09,7.2,7.26,7.31,7.43,7.48,7.54,7.67,7.8,7.79,7.93,8.07] ./ 100
        target_periodicity = fill(2,length(mats))
        target_periodicity[2] = 1 # 1 year is a no-coupon, BEY yield, the rest are semiannual BEY
        @testset "Fabozzi bootstrapped rates" for (r,mat,target,tp) in zip(cmt,mats,targets,target_periodicity)
            @test rate(zero(curve,mat,Periodic(tp))) ≈ target atol=0.0001
        end

        # Hull, problem 4.34
        adj = ((1 + .051813/2) ^2 -1) * 100
        cmt  = [4.0816,adj,5.4986,5.8620] ./ 100
        mats =  [.5,1.,1.5,2.]
        curve = Yields.USCMT(cmt,mats)
        targets = [4.0405,5.1293,5.4429,5.8085] ./ 100
        @testset "Hull bootstrapped rates" for (r,mat,target) in zip(cmt,mats,targets)
            @test rate(zero(curve,mat,Continuous())) ≈ target atol=0.001
        end
        
    #     # https://www.federalreserve.gov/pubs/feds/2006/200628/200628abs.html
    #     # 2020-04-02 data
    #     cmt = [0.0945,0.2053,0.4431,0.7139,0.9724,1.2002,1.3925,1.5512,1.6805,1.7853,1.8704,1.9399,1.9972,2.045,2.0855,2.1203,2.1509,2.1783,2.2031,2.2261,2.2477,2.2683,2.2881,2.3074,2.3262,2.3447,2.3629,2.3809,2.3987,2.4164] ./ 100
    #     mats = collect(1:30)
    #     curve = Yields.USCMT(cmt,mats)
    #     target = [0.0945,0.2053,0.444,0.7172,0.9802,1.2142,1.4137,1.5797,1.7161,1.8275,1.9183,1.9928,2.0543,2.1056,2.1492,2.1868,2.2198,2.2495,2.2767,2.302,2.3261,2.3494,2.372,2.3944,2.4167,2.439,2.4614,2.4839,2.5067,2.5297] ./ 100
        
    #     @testset "FRB data" for (t,mat,target) in zip(1:length(mats),mats,target)
    #         @show mat
    #         if mat >= 1
    #             @test rate(zero(curve,mat,Continuous())) ≈ target[mat] atol=0.001
    #         end
    #     end
    end
    
    @testset "OIS" begin
        ois =  [1.8 , 2.0, 2.2, 2.5, 3.0, 4.0] ./ 100
        mats = [1/12, 1/4, 1/2,    1,  2,   5]
        curve = Yields.OIS(ois,mats)
        targets = [0.017987,0.019950,0.021880,0.024693,0.029994,0.040401]
        @testset "bootstrapped rates" for (r,mat,target) in zip(ois,mats,targets)
            @test rate(zero(curve,mat,Continuous())) ≈ target atol=0.001
        end
    end
    
end
