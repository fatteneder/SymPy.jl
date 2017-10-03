"""

Plotting of symbolic objects.

The `Plots` package provide a uniform interface to many of `Julia`'s
plotting packages. `SymPy` plugs into `Plots`' "recipes."

The basic goal is that when `Plots` provides an interface for function
objects, this package extends the interface to symbolic expressions.

In particular:


* `plot(ex::Sym, a, b; kwargs...)` will plot a function evaluating `ex` over [a,b]

Example. Here we use the default backend for `Plots` to make a plot:

```
using Plots
@vars x
plot(x^2 - 2x, 0, 4)
```



* `plot(ex1, ex2, a, b; kwargs...)` will plot the two expressions in a parametric plot over the interval `[a,b]`.

Example:

```
@vars x
plot(sin(2x), cos(3x), 0, 4pi) ## also
```

For a few backends (those that support `:path3d`) a third symbolic
expression may be added to have a 3d parametric plot rendered:

```
plot(sin(x), cos(x), x, 0, 4pi) # helix in 3d
```

* `plot(xs, ys, expression)` will make a contour plot (for many backends).

```
@vars x y
plot(linspace(0,5), linspace(0,5), x*y)
```



* To plot the surface  `z=ex(x,y)` over a region we have `Plots.surface`. For example,

```
@vars x y
surface(-5:5, -5:5, 25 - x^2 - y^2)
```

* a vectorfield plot can (inefficiently but directly) be produced following this example:

```
function vfieldplot(fx, fy; xlim=(-5,5), ylim=(-5,5), n=7)
    xs = linspace(xlim..., n)
    ys = linspace(ylim..., n)

    us = vec([x for x in xs, y in ys])
    vs = vec([y for x in xs, y in ys])
    fxs = vec([fx(x,y) for x in xs, y in ys])
    fys = vec([fy(x,y) for x in xs, y in ys])

    quiver(us, vs, quiver=(fxs, fys))
end
fx = (x + y) / sqrt(x^2 + y^2)
fy = (x - y) / sqrt(x^2 + y^2)
vfieldplot(fx, fy)
```


* To plot two or more functions at once, the style `plot([ex1, ex2], a, b)` does not work. Rather, use
    `plot(ex1, a, b); plot!(ex2)`, as in:
    
```
@vars x
plot(sin(x), 0, 2pi)
plot!(cos(x))
```
----

Some graphics provided by `SymPy` are available if `PyPlot` is installed.


* `plot_parametric_surface(exs::Tuple, (uvar,a0,b0), (vvar,a1,b1);
  kwargs)` will make parametrically defined surface plots.

Plot the parametrically defined surface `[exs[1](u,v), exs[2](u,v), exs[3](u,v)]` over `[a0,a1] x
[b0,b1]`. The specification of the variables uses a tuple of the form
`(Sym, Real, Real)` following the style of SymPy in `integrate`, say,
where disambiguation of variable names is needed.

```
@vars theta, phi
r = 1
plot_parametric_surface((r*sin(theta)*sin(phi), r*sin(theta)*cos(phi), r*cos(theta)),
                        (theta, 0, pi), (phi, 0, pi/2))
```

(The SymPy name for this function is `plot3d_parametric_surface`, we have dropped the "`3d`" part.)


* `plot_implicit(equation, (xvar, x0, x1), (yvar, y0, y1))` will plot implicitly the equation.

```
@syms x y
plot_implicit(Eq(x^2+ y^2,3), (x, -2, 2), (y, -2, 2))  # draw a circle
```


"""
sympy_plotting = nothing
export sympy_plotting


## Recipes for hooking into Plots

using RecipesBase

##
@recipe f{T<:Sym}(::Type{T}, v::T) = lambdify(v)

## for vectors of expressions
## This does not work. See: https://github.com/JuliaPlots/RecipesBase.jl/issues/19
#@recipe f(ss::AbstractVector{Sym}) = lambdify.(ss)
#@recipe  function f{T<:Array{Sym,1}}(::Type{T}, ss::T)  Function[lambdify(s) for s in ss]  end

## A vector field plot can be visualized as an n × n collection of arrows
## over the region xlims × ylims
## These arrows are defined by:
## * fx, fy giving the components of each. These are callbable objects, such as
##   (x,y) -> sin(y)
## * Fyx  A function F(y,x), useful for visualizing first-order ODE y'=F(y(x),x).
##   note reverse order of y and x.
## The vectors are scaled so as not to overlap.

"""
`VectorField(fx, fy`): create an object that can be `plot`ted as a vector field.

A vectorfield plot draws arrows at grid points proportional to `[fx(x_i,y_i), fy(x_i,y_i)]` to visualize the field generated by `[fx, fy]`.

The plot command: `plot(VectorField(fx, fy), xlims=(-5,5), ylims=(-5,5), n=8)` will draw the vectorfield. This uses the default values, so the same graph would be rendered by `plot(VectorField(fx,fy))`.

To faciliate the visualization of solution to the ODE y' = F(x, y(x)), the call `plot(VectorField(F))` will work. (The order is x then y, though often this is written as F(y(x),x).)

`SymPy` objects can be passed to `VectorField`, but this is a bit
fragile, as they must each have two variables so that they can be
called with two variables.  (E.g., `y(1,2)` will be `1` not `2`, as
might be intended.)

Examples:
```
using Plots

fx(x,y) = sin(y); fy(x,y) = cos(y)
plot(VectorField(fx, fy), xlims=(-2pi, 2pi), ylims=(-2pi,2pi))

# plot field of y' = 3y*x over (-5,5) x (-5,5)
F(x,y) = 3*y*x
plot(VectorField(F))

# plot field and solution u' = u*(1-u)
u = SymFunction("u"); @vars x
F(x,y) = y*(1-y)
out = dsolve(u'(x) - F(x, u(x)), x, (u, 0, 1))
plot(VectorField(F), xlims=(0,5), ylims=(0,2))
plot!(rhs(out))
```

"""
immutable VectorField
    fx
    fy
end
VectorField(f) = VectorField((x,y) -> 1.0, f)
export VectorField

@recipe function f(F::VectorField; n=8)

    xlims = get(plotattributes,:xlims, (-5,5))
    ylims = get(plotattributes, :ylims, (-5,5))
    
    xs = repeat(linspace(xlims[1], xlims[2], n), inner=(n,))
    ys = repeat(linspace(ylims[1], ylims[2], n), outer=(n,))

    us, vs = broadcast(F.fx, xs, ys), broadcast(F.fy, xs, ys)

    delta = min((xlims[2]-xlims[1])/n, (ylims[2]-ylims[1])/n)
    m = maximum([norm([u,v]) for (u,v) in zip(us, vs)])
    
    lambda = delta / m

    x := xs
    y := ys
    quiver := (lambda*us, lambda*vs)
    seriestype := :quiver
    ()
end


## ---------------------



## These functions give acces to SymPy's plotting module. They will work if PyPlot is installed, but may otherwise cause an error

## surface plot xvar = Tuple(Sym, Real, Real)
##
"""

Render a parametrically defined surface plot.

Example:
```
@vars u, v
plot_parametric_surface((u*v,u-v,u+v), (u,0,1), (v,0,1))
```

This uses `PyPlot`, not `Plots` for now.
"""
function plot_parametric_surface(exs::(@compat Tuple{Sym,Sym,Sym}),
                                 xvar=(-5.0, 5.0),
                                 yvar=(-5.0, 5.0),
                                 args...;
                                 kwargs...)

    SymPy.call_sympy_fun(sympy["plotting"]["plot3d_parametric_surface"], exs..., args...; kwargs...)

end
export plot_parametric_surface





"""
Plot an implicit equation

```
@syms x y
plot_implicit(Eq(x^2+ y^2,3), (x, -2, 2), (y, -2, 2))
```

"""
plot_implicit(ex, args...; kwargs...) = SymPy.call_sympy_fun(sympy["plotting"]["plot_implicit"], ex, args...; kwargs...)
export plot_implicit
