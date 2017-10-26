NLsolve.jl
==========

[![Build Status](https://travis-ci.org/JuliaNLSolvers/NLsolve.jl.svg?branch=master)](https://travis-ci.org/JuliaNLSolvers/NLsolve.jl)

The NLsolve package solves systems of nonlinear equations. Formally, if `f` is
a multivariate function, then this package looks for some vector `x` that
satisfies `f(x)=0`.

The package is also able to solve mixed complementarity problems, which are
similar to systems of nonlinear equations, except that the equality to zero is
allowed to become an inequality if some boundary condition is satisfied. See
further below for a formal definition and the related commands.

Since there is some overlap between optimizers and nonlinear solvers, this
package borrows some ideas from the
[Optim](https://github.com/JuliaNLSolvers/Optim.jl) package, and depends on it for
linesearch algorithms.

# Simple example

We consider the following bivariate function of two variables:

```jl
(x, y) -> ((x+3)*(y^3-7)+18, sin(y*exp(x)-1))
```

In order to find a zero of this function and display it, you would write the
following program:

```jl
using NLsolve

function f!(fvec, x)
    fvec[1] = (x[1]+3)*(x[2]^3-7)+18
    fvec[2] = sin(x[2]*exp(x[1])-1)
end

function j!(fjac, x)
    fjac[1, 1] = x[2]^3-7
    fjac[1, 2] = 3*x[2]^2*(x[1]+3)
    u = exp(x[1])*cos(x[2]*exp(x[1])-1)
    fjac[2, 1] = x[2]*u
    fjac[2, 2] = u
end

nlsolve(f!, j!, [ 0.1; 1.2])
```

First, note that the function `f!` computes the residuals of the nonlinear
system, and stores them in a preallocated vector passed as second argument.
Similarly, the function `j!` computes the Jacobian of the system and stores it
in a preallocated matrix passed as second argument. Residuals and Jacobian
functions can take different shapes, see below.

Second, when calling the `nlsolve` function, it is necessary to give a starting
point to the iterative algorithm.

Finally, the `nlsolve` function returns an object of type `SolverResults`. In
particular, the field `zero` of that structure contains the solution if
convergence has occurred. If `r` is an object of type `SolverResults`, then
`converged(r)` indicates if convergence has occurred.

# Specifying the function and its Jacobian

There are various ways of specifying the residuals function and possibly its
Jacobian.

## With functions modifying arguments in-place

This is the most efficient method, because it minimizes the memory allocations.

In the following, it is assumed that you have defined a function
`f!(x::AbstractVector, fx::AbstractVector)` or, more generally,
`f!(x::AbstractArray, fx::AbstractArray)` computing the residual of the system
at point `x` and putting it into the `fx` argument.

In turn, there 3 ways of specifying how the Jacobian should be computed:

### Finite differencing

If you do not have a function that compute the Jacobian, it is possible to
have it computed by finite difference. In that case, the syntax is simply:

```jl
nlsolve(f!, initial_x)
```

Alternatively, you can construct an object of type
`DifferentiableVector` and pass it to `nlsolve`, as in:

```jl
df = DifferentiableVector(f!)
nlsolve(df, initial_x)
```

If your function `f!` operates not on `AbstractVector` but on arbitrary
`AbstractArray` you have to specify `initial_x` in the constructor of the
`DifferentiableVector`:

```jl
df = DifferentiableVector(f!, initial_x)
nlsolve(df, initial_x)
```

### Automatic differentiation

Another option if you do not have a function computing the Jacobian is to use
automatic differentiation, thanks to the `ForwardDiff` package. The syntax is
simply:

```jl
nlsolve(f!, initial_x, autodiff = true)
```

### Jacobian available

If, in addition to `f!(x::AbstractVector, fx::AbstractVector)`, you have a
function `j!(x::AbstractVector, gx::AbstractMatrix)` for computing the Jacobian
of the system, then the syntax is, as in the example above:

```jl
nlsolve(f!, j!, initial_x)
```

Again it is also possible to specify two functions `f!(x::AbstractArray,
fx::AbstractArray)` and `j!(x::AbstractArray, gx::AbstractMatrix)` that work on
arbitrary arrays `x`.

Note that you should not assume that the Jacobian `gx` passed in argument is
initialized to a zero matrix. You must set all the elements of the matrix in
the function `j!`.

Alternatively, you can construct an object of type
`DifferentiableVector` and pass it to `nlsolve`, as in:

```jl
df = DifferentiableVector(f!, j!)
nlsolve(df, initial_x)
```

If `f!` and `j!` do not operate on vectors the syntax is:

```jl
df = DifferentiableVector(f!, j!, initial_x)
nlsolve(df, initial_x)
```

### Optimization of simultaneous residuals and Jacobian

If, in addition to `f!` and `j!`, you have a function `fj!(x::AbstractVector,
fx::AbstractVector, gx::AbstractMatrix)` or `fj!(x::AbstractArray,
fx::AbstractArray, gx::AbstractMatrix)` that computes both the residual and the
Jacobian at the same time, you can use the following syntax for vectors

```jl
df = DifferentiableVector(f!, j!, fj!)
nlsolve(df, initial_x)
```

and similarly for arbitrary arrays

```jl
df = DifferentiableVector(f!, j!, fj!, initial_x)
nlsolve(df, initial_x)
```

If the function `fj!` uses some optimization that make it costless than
calling `f!` and `j!` successively, then this syntax can possibly improve the
performance.

### Other combinations

There are other helpers for two other cases, described below. Note that these
cases are not optimal in terms of memory management.

If only `f!` and `fj!` are available, the helper function `only_f!_and_fj!` can be
used to construct a `DifferentiableVector` object, that can be
used as first argument of `nlsolve`. The complete syntax is therefore

```jl
nlsolve(only_f!_and_fj!(f!, fj!), initial_x)
```

if `f!` and `fj!` operate on vectors, and otherwise

```jl
nlsolve(only_f!_and_fj!(f!, fj!, initial_x), initial_x)
```

If only `fj!` is available, the helper function `only_fj!` can be used to
construct a `DifferentiableVector` object, that can be used as
first argument of `nlsolve`. The complete syntax is therefore

```jl
nlsolve(only_fj!(fj!), initial_x)
```

if `f!` and `fj!` operate on vectors, and otherwise

```jl
nlsolve(only_fj!(f!, fj!, initial_x), initial_x)
```

## With functions returning residuals and Jacobian as output

Here it is assumed that you have a function `f(x::AbstractVector)` that returns
a newly-allocated vector containing the residuals. The helper function
`not_in_place` can be used to construct a function, that can be used as first
argument of `nlsolve`. The complete syntax is therefore:

```jl
nlsolve(not_in_place(f), initial_x)
```

If `f` does not operate on vectors but on arbitrary arrays the syntax is

```jl
nlsolve(not_in_place(f, initial_x), initial_x)
```

Via the `autodiff` keyword both finite-differencing and autodifferentiation can
be used to compute the Jacobian in that case.

If, in addition to `f(x::AbstractVector)`, there is a function
`g(x::AbstractVector)` returning a newly-allocated matrix containing the
Jacobian, `not_in_place` can be used to construct an object of type
`DifferentiableVector` that can be used as first argument of
`nlsolve`:

```jl
nlsolve(not_in_place(f, g), initial_x)
```

For functions `f` and `g` that operate on arbitrary arrays the syntax is:

```jl
nlsolve(not_in_place(f, g, initial_x), initial_x)
```

If, in addition to `f` and `g`, there is a function `fg` returning a tuple of a
newly-allocated vector of residuals and a newly-allocated matrix of the
Jacobian, `not_in_place` can be used to construct an object of type
`DifferentiableVector`:

```jl
nlsolve(not_in_place(f, g, fg), initial_x)
```

For functions `f`, `g`, and `fg` that operate on arbitrary arrays the syntax is:

```jl
nlsolve(not_in_place(f, g, fg, initial_x), initial_x)
```

## With functions taking several scalar arguments

If you have a function `f(x::Float64, y::Float64, ...)` that takes the point of
interest as several scalars and returns a vector or a tuple containing the
residuals, you can use the helper function `n_ary`. The complete syntax is
therefore:

```jl
nlsolve(n_ary(f), initial_x)
```

Finite-differencing is used to compute the Jacobian.

## If the Jacobian is sparse

If the Jacobian of your function is sparse, it is possible to ask the routines
to manipulate sparse matrices instead of full ones, in order to increase
performance on large systems. This can be achieved by constructing an object of
type `DifferentiableSparseMultivariateFunction`. The syntax is therefore

```jl
df = DifferentiableSparseMultivariateFunction(f!, j!)
nlsolve(df, initial_x)
```

if `f!` and `j!` operate on vectors, and otherwise

```jl
df = DifferentiableSparseMultivariateFunction(f!, j!, initial_x)
nlsolve(df, initial_x)
```

It is possible to give an optional third function `fj!` to the constructor, as
for the full Jacobian case.

The second argument of `j!` (and the third of `fj!`) is assumed to be of the
same type as the one returned by the function `spzeros` (i.e.
`SparseMatrixCSC`).

Note that on the first call to `j!` or `fj!`, the sparse matrix passed in
argument is empty, i.e. all its elements are zeros. But this matrix is not
reset across function calls. So you need to be careful and ensure that you
don't forget to overwrite all nonzeros elements that could have been
initialized by a previous function call. If in doubt, you can clear the sparse
matrix at the beginning of the function. If `gx` is the sparse Jacobian, this
can be achieved with:

```jl
fill!(gx.colptr, 1)
empty!(gx.rowval)
empty!(gx.nzval)
```

Another solution is to directly pass a Jacobian matrix with a given sparsity. To
do so, construct an object of type
`DifferentiableGivenSparseMultivariateFunction` by

```jl
df = DifferentiableGivenSparseMultivariateFunction(f!, j!, J)
nlsolve(df, initial_x)
```

if `f!` and `j!` operate on vectors, and otherwise

```jl
df = DifferentiableGivenSparseMultivariateFunction(f!, j!, J, initial_x)
nlsolve(df, initial_x)
```

If `j!` conserves the sparsity structure of `gx`, `gx` will always have the same
sparsity as `J`. This sometimes allow to write a faster version of `j!`.

# Fine tunings

Three algorithms are currently available. The choice between these is achieved
by setting the optional `method` argument of `nlsolve`. The default algorithm
is the trust region method.

## Trust region method

This is the well-known solution method which relies on a quadratic
approximation of the least-squares objective, considered to be valid over a
compact region centered around the current iterate.

This method is selected with `method = :trust_region`.

This method accepts the following custom parameters:

* `factor`: determines the size of the initial trust region. This size is set
  to the product of factor and the euclidean norm of `initial_x` if nonzero, or
  else to factor itself. Default: `1.0`.
* `autoscale`: if `true`, then the variables will be automatically rescaled.
  The scaling factors are the norms of the Jacobian columns. Default: `true`.

## Newton method with linesearch

This is the classical Newton algorithm with optional linesearch.

This method is selected with `method = :newton`.

This method accepts a custom parameter `linesearch!`, which must be equal to a
function computing the linesearch. Currently, available values are taken from
the [`LineSearches`](https://github.com/JuliaNLSolvers/LineSearches.jl) package.
By default, no linesearch is performed.
**Note:** it is assumed that a passed linesearch function will at least update the solution
vector and evaluate the function at the new point.

## Anderson acceleration

Also known as DIIS or Pulay mixing, this method is based on the
acceleration of the fixed-point iteration `xn+1 = xn + β f(xn)`, where
by default `β=1`. It does not use Jacobian information or linesearch,
but has a history whose size is controlled by the `m` parameter: `m=0`
(the default) corresponds to the simple fixed-point iteration above,
and higher values use a larger history size to accelerate the
iterations. Higher values of `m` usually increase the speed of
convergence, but increase the storage and computation requirements and
might lead to instabilities. This method is useful to accelerate a
fixed-point iteration `xn+1 = g(xn)` (in which case use this solver
with `f(x) = g(x) - x`).

Reference: H. Walker, P. Ni, Anderson acceleration for fixed-point
iterations, SIAM Journal on Numerical Analysis, 2011

## Common options

Other optional arguments to `nlsolve`, available for all algorithms, are:

* `xtol`: norm difference in `x` between two successive iterates under which
  convergence is declared. Default: `0.0`.
* `ftol`: infinite norm of residuals under which convergence is declared.
  Default: `1e-8`.
* `iterations`: maximum number of iterations. Default: `1_000`.
* `store_trace`: should a trace of the optimization algorithm's state be
  stored? Default: `false`.
* `show_trace`: should a trace of the optimization algorithm's state be shown
  on `STDOUT`? Default: `false`.
* `extended_trace`: should additional algorithm internals be added to the state
  trace? Default: `false`.

# Mixed complementarity problems

Given a multivariate function `f` and two vectors `a` and `b`, the solution to
the mixed complementarity problem (MCP) is a vector `x` such that one of the
following holds for every index `i`:

* either `f_i(x) = 0` and `a_i <= x_i <= b_i`
* or `f_i(x) > 0` and `x_i = a_i`
* or `f_i(x) < 0` and `x_i = b_i`

The vector `a` can contain elements equal to `-Inf`, while the vector
`b` can contain elements equal to `Inf`. In the particular case where all
elements of `a` are equal to `-Inf`, and all elements of `b` are equal to
`Inf`, the MCP is exactly equivalent to the multivariate root finding problem
described above.

The package solves MCPs by reformulating them as the solution to a system of
nonlinear equations (as described by Miranda and Fackler, 2002, though NLsolve
uses the sign convention opposite to theirs).

The function `mcpsolve` solves MCPs. It takes the same arguments as `nlsolve`,
except that the vectors `a` and `b` must immediately follow the argument(s)
corresponding to `f` (and possibly its derivative). There is also an extra
optional argument `reformulation`, which can take two values:

* `reformulation = :smooth`: use a smooth reformulation of the problem using
  the Fischer function. This is the default, since it is more robust for complex
  problems.
* `reformulation = :minmax`: use a min-max reformulation of the problem. It is
  faster than the smooth approximation, since it uses less algebra, but is less
  robust since the reformulated problem has kinks.

Here is a complete example:

```jl
using NLsolve

function f!(fvec, x)
    fvec[1]=3*x[1]^2+2*x[1]*x[2]+2*x[2]^2+x[3]+3*x[4]-6
    fvec[2]=2*x[1]^2+x[1]+x[2]^2+3*x[3]+2*x[4]-2
    fvec[3]=3*x[1]^2+x[1]*x[2]+2*x[2]^2+2*x[3]+3*x[4]-1
    fvec[4]=x[1]^2+3*x[2]^2+2*x[3]+3*x[4]-3
end

r = mcpsolve(f!, [0., 0., 0., 0.], [Inf, Inf, Inf, Inf],
             [1.25, 0., 0., 0.5], reformulation = :smooth, autodiff = true)
```

The solution is:

```jl
julia> r.zero
4-element Array{Float64,1}:
  1.22474
  0.0
 -1.378e-19
  0.5
```

The lower bounds are hit for the second and third components, hence the second
and third components of the function are positive at the solution. On the other
hand, the first and fourth components of the function are zero at the solution.

```jl
julia> fvec = similar(r.zero)

julia> f!(r.zero, fvec)

julia> fvec
4-element Array{Float64,1}:
 -1.26298e-9
  3.22474
  5.0
  3.62723e-11
```

# Todolist

* Broyden updating of Jacobian in trust-region
* Homotopy methods
* [LMMCP algorithm by C. Kanzow](http://www.mathematik.uni-wuerzburg.de/~kanzow/)
* QR updating of the least-squares problem in the Anderson acceleration solver

# Related Packages

* [JuMP.jl](https://github.com/JuliaOpt/JuMP.jl) can also solve non linear equations. Just reformulate your problem as an optimization problem with non linear constraints: use the set of equations as constraints, and enter 1.0 as the objective function. JuMP currently supports a number of open-source and commercial solvers.
* [Complementarity.jl](https://github.com/chkwon/Complementarity.jl) brings the powerful modeling language of JuMP.jl to complementarity problems. It supports two solvers: [PATHSolver.jl](https://github.com/chkwon/PATHSolver.jl) and NLsolve.jl.

# References

Nocedal, Jorge and Wright, Stephen J. (2006): "Numerical Optimization", second
edition, Springer

[MINPACK](http://www.netlib.org/minpack/) by Jorge More', Burt Garbow, and Ken
Hillstrom at Argonne National Laboratory

Miranda, Mario J. and Fackler, Paul L. (2002): "Applied Computational Economics
and Finance", MIT Press
