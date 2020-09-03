using LinearAlgebra
### AbstractDiffEqOperator Interface

#=
1. Function call and multiplication: L(du, u, p, t) for inplace and du = L(u, p, t) for
   out-of-place, meaning L*u and mul!(du, L, u).
2. If the operator is not a constant, update it with (u,p,t). A mutating form, i.e.
   update_coefficients!(A,u,p,t) that changes the internal coefficients, and a
   out-of-place form B = update_coefficients(A,u,p,t).
3. isconstant(A) trait for whether the operator is constant or not.
4. islinear(A) trait for whether the operator is linear or not.
=#

Base.eltype(L::AbstractDiffEqOperator{T}) where T = T
update_coefficients!(L,u,p,t) = nothing
update_coefficients(L,u,p,t) = L

# Traits
isconstant(::AbstractDiffEqOperator) = false
islinear(::AbstractDiffEqOperator) = false
has_expmv!(L::AbstractDiffEqOperator) = false # expmv!(v, L, t, u)
has_expmv(L::AbstractDiffEqOperator) = false # v = exp(L, t, u)
has_exp(L::AbstractDiffEqOperator) = false # v = exp(L, t)*u
has_mul(L::AbstractDiffEqOperator) = true # du = L*u
has_mul!(L::AbstractDiffEqOperator) = false # mul!(du, L, u)
has_ldiv(L::AbstractDiffEqOperator) = false # du = L\u
has_ldiv!(L::AbstractDiffEqOperator) = false # ldiv!(du, L, u)

### AbstractDiffEqLinearOperator Interface

#=
1. AbstractDiffEqLinearOperator <: AbstractDiffEqOperator
2. Can absorb under multiplication by a scalar. In all algorithms things like
   dt*L show up all the time, so the linear operator must be able to absorb
   such constants.
4. isconstant(A) trait for whether the operator is constant or not.
5. Optional: diagonal, symmetric, etc traits from LinearMaps.jl.
6. Optional: exp(A). Required for simple exponential integration.
7. Optional: expmv(A,u,p,t) = exp(t*A)*u and expmv!(v,A::DiffEqOperator,u,p,t)
   Required for sparse-saving exponential integration.
8. Optional: factorizations. A_ldiv_B, factorize et. al. This is only required
   for algorithms which use the factorization of the operator (Crank-Nicolson),
   and only for when the default linear solve is used.
=#

# Extra standard assumptions
isconstant(::AbstractDiffEqLinearOperator) = true
islinear(o::AbstractDiffEqLinearOperator) = isconstant(o)

# Other ones from LinearMaps.jl
# Generic fallbacks
LinearAlgebra.exp(L::AbstractDiffEqLinearOperator,t) = exp(t*L)
has_exp(L::AbstractDiffEqLinearOperator) = true
expmv(L::AbstractDiffEqLinearOperator,u,p,t) = exp(L,t)*u
expmv!(v,L::AbstractDiffEqLinearOperator,u,p,t) = mul!(v,exp(L,t),u)
# Factorizations have no fallback and just error

"""
AffineDiffEqOperator{T} <: AbstractDiffEqOperator{T}

`Ex: (A₁(t) + ... + Aₙ(t))*u + B₁(t) + ... + Bₙ(t)`

AffineDiffEqOperator{T}(As,Bs,du_cache=nothing)

Takes in two tuples for split Affine DiffEqs

1. update_coefficients! works by updating the coefficients of the component
   operators.
2. Function calls L(u, p, t) and L(du, u, p, t) are fallbacks interpretted in this form.
   This will allow them to work directly in the nonlinear ODE solvers without
   modification.
3. f(du, u, p, t) is only allowed if a du_cache is given
4. B(t) can be Union{Number,AbstractArray}, in which case they are constants.
   Otherwise they are interpreted they are functions v=B(t) and B(v,t)

Solvers will see this operator from integrator.f and can interpret it by
checking the internals of As and Bs. For example, it can check isconstant(As[1])
etc.
"""
struct AffineDiffEqOperator{T,T1,T2,U} <: AbstractDiffEqOperator{T}
    As::T1
    Bs::T2
    du_cache::U
    function AffineDiffEqOperator{T}(As,Bs,du_cache=nothing) where T
        all([size(a) == size(As[1])
             for a in As]) || error("Operator sizes do not agree")
        new{T,typeof(As),typeof(Bs),typeof(du_cache)}(As,Bs,du_cache)
    end
end

Base.size(L::AffineDiffEqOperator) = size(L.As[1])


function (L::AffineDiffEqOperator)(u,p,t::Number)
    tmp = sum((update_coefficients(A,u,p,t); A*u for A in L.As))
    tmp2 = sum((typeof(B) <: Union{Number,AbstractArray} ? B : B(t) for B in L.Bs))
    tmp + tmp2
end

function (L::AffineDiffEqOperator)(du,u,p,t::Number)
    update_coefficients!(L,u,p,t)
    L.du_cache === nothing && error("Can only use inplace AffineDiffEqOperator if du_cache is given.")
    du_cache = L.du_cache
    fill!(du,zero(first(du)))
    # TODO: Make type-stable via recursion
    for A in L.As
        mul!(du_cache,A,u)
        du .+= du_cache
    end
    for B in L.Bs
        if typeof(B) <: Union{Number,AbstractArray}
            du .+= B
        else
            B(du_cache,t)
            du .+= du_cache
        end
    end
end

function update_coefficients!(L::AffineDiffEqOperator,u,p,t)
    # TODO: Make type-stable via recursion
    for A in L.As; update_coefficients!(A,u,p,t); end
    for B in L.Bs; update_coefficients!(B,u,p,t); end
end

@deprecate is_constant(L::AbstractDiffEqOperator) isconstant(L)
