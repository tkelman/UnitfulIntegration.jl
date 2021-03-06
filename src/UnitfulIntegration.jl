__precompile__(true)
module UnitfulIntegration

using Unitful
import Unitful: DimensionError
import QuadGK

function QuadGK.quadgk(f, a::Quantity, b::Quantity, c::Quantity...; kws...)
    d = dimension(a)
    d != dimension(b) && throw(DimensionError(a,b))
    for x in c
        d != dimension(x) && throw(DimensionError(a,x))
    end
    QuadGK.quadgk(f, promote(a,b,c...)...; kws...)
end

function QuadGK.quadgk{T<:AbstractFloat,D,U}(f, a::Quantity{T,D,U},
    b::Quantity{T,D,U}, c::Quantity{T,D,U}...; abstol=NaN, reltol=sqrt(eps(T)),
    maxevals=10^7, order=7, norm=vecnorm)
    if isnan(abstol)
        error("must provide an explicit abstol keyword argument, e.g. ",
              "`zero(f(a)*a)` supposing f is defined at a.")
    end
    _do_quadgk(f, [a, b, c...], order, T, abstol, reltol, maxevals, norm)
end

function QuadGK.quadgk{T<:AbstractFloat,D,U}(f, a::Quantity{Complex{T},D,U},
    b::Quantity{Complex{T},D,U}, c::Quantity{Complex{T},D,U}...; abstol=NaN,
    reltol=sqrt(eps(T)), maxevals=10^7, order=7, norm=vecnorm)
    if isnan(abstol)
        error("must provide an explicit abstol keyword argument, e.g. ",
              "`zero(f(a)*a)` supposing f is defined at a.")
    end
    _do_quadgk(f, [a, b, c...], order, T, abstol, reltol, maxevals, norm)
end

# Necessary with infinite or semi-infinite intervals since quantities !<: Real
function _do_quadgk{Tw,T<:Real,D,U}(f, s::Array{Quantity{T,D,U},1}, n, ::Type{Tw},
    abstol, reltol, maxevals, nrm)

    s_no_u = reinterpret(T, s)
    s1 = s_no_u[1]; s2 = s_no_u[end]; inf1 = isinf(s1); inf2 = isinf(s2)
    if inf1 || inf2
        if inf1 && inf2 # x = t/(1-t^2) coordinate transformation
            return QuadGK.do_quadgk(t -> begin t2 = t*t; den = 1 / (1 - t2);
                                    f(t*den*U())*U() * (1+t2)*den*den; end,
                             map(x -> isinf(x) ? copysign(one(x), x) :
                                 2x / (1+hypot(1,2x)), s_no_u),
                             n, T, abstol, reltol, maxevals, nrm)
        end
        s0,si = inf1 ? (s2,s1) : (s1,s2)
        if si < 0 # x = s0 - t/(1-t)
            return QuadGK.do_quadgk(t -> begin den = 1 / (1 - t);
                                    f((s0 - t*den)*U())*U() * den*den; end,
                             reverse!(map(x -> 1 / (1 + 1 / (s0 - x)), s_no_u)),
                             n, T, abstol, reltol, maxevals, nrm)
        else # x = s0 + t/(1-t)
            return QuadGK.do_quadgk(t -> begin den = 1 / (1 - t);
                                    f((s0 + t*den)*U())*U() * den*den; end,
                             map(x -> 1 / (1 + 1 / (x - s0)), s_no_u),
                             n, T, abstol, reltol, maxevals, nrm)
        end
    end
    QuadGK.do_quadgk(f, s, n, Tw, abstol, reltol, maxevals, nrm)
end

_do_quadgk{Tw}(f, s, n, ::Type{Tw}, abstol, reltol, maxevals, nrm) =
    QuadGK.do_quadgk(f, s, n, Tw, abstol, reltol, maxevals, nrm)

end # module
