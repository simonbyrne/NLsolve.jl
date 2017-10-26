# test use of arbitrary arrays with Wood example from MINPACK

@testset "abstractarray" begin

const c3 = 2e2
const c4 = 2.02e1
const c5 = 1.98e1
const c6 = 1.8e2

function f!(F, x)
    temp1 = x[2] - x[1]^2
    temp2 = x[4] - x[3]^2
    F[1] = -c3*x[1]*temp1 - (1 - x[1])
    F[2] = c3*temp1 + c4*(x[2] - 1) + c5*(x[4] - 1)
    F[3] = -c6*x[3]*temp2 - (1 - x[3])
    F[4] = c6*temp2 + c4*(x[4] - 1) + c5*(x[2] - 1)
end

function j!(J, x)
    fill!(J, 0)
    temp1 = x[2] - 3x[1]^2
    temp2 = x[4] - 3x[3]^2
    J[1,1] = -c3*temp1 + 1
    J[1,2] = -c3*x[1]
    J[2,1] = -2*c3*x[1]
    J[2,2] = c3 + c4
    J[2,4] = c5
    J[3,3] = -c6*temp2 + 1
    J[3,4] = -c6*x[3]
    J[4,2] = c5
    J[4,3] = -2*c6*x[3]
    J[4,4] = c6 + c4
end

initial_x_matrix = [-3. -3; -1 -1]
initial_x = vec(initial_x_matrix)
initial_x_wrapped = WrappedArray(initial_x_matrix)

for method in (:trust_region, :newton, :anderson)
    r = nlsolve(f!, j!, initial_x, method = method)
    r_matrix = nlsolve(f!, j!, initial_x_matrix, method = method)
    r_wrapped = nlsolve(f!, j!, initial_x_wrapped, method = method)

    @test r.zero == vec(r_matrix.zero)
    @test r_matrix.zero == r_wrapped.zero
    @test r.residual_norm == r_matrix.residual_norm
    @test r.residual_norm == r_wrapped.residual_norm
    @test typeof(r.zero) == typeof(initial_x)
    @test typeof(r_matrix.zero) == typeof(initial_x_matrix)
    @test typeof(r_wrapped.zero) == typeof(initial_x_wrapped)

    r_AD = nlsolve(f!, initial_x, method = method, autodiff = true)
    r_matrix_AD = nlsolve(f!, initial_x_matrix, method = method, autodiff = true)
    r_wrapped_AD = nlsolve(f!, initial_x_wrapped, method = method, autodiff = true)

    @test r_AD.zero == vec(r_matrix_AD.zero)
    @test r_matrix_AD.zero == r_wrapped_AD.zero
    @test r_AD.residual_norm == r_matrix_AD.residual_norm
    @test r_AD.residual_norm == r_wrapped_AD.residual_norm
    @test typeof(r_AD.zero) == typeof(initial_x)
    @test typeof(r_matrix_AD.zero) == typeof(initial_x_matrix)
    @test typeof(r_wrapped_AD.zero) == typeof(initial_x_wrapped)
end

end
