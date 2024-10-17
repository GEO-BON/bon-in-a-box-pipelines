function create_diagnostics(model, predictors, presence_layer, pseudoabsences, confusion_matrices)
    t = tuning_curve(confusion_matrices)
    c = corners(predictors, presence_layer, pseudoabsences)
    t, c
end 

function tuning_curve(M)
    f = Figure()
    ax = Axis(f[1, 1], xlabel="Threshold", ylabel="MCC")
    T = LinRange(0.0, 1.0, 250)
    lines!(ax, T, vec(mean(mcc.(M); dims=2)))
    f
end


function _env_correlation_plot(
    g, 
    predictors, 
    p1, 
    p2, 
    presences, 
    absences;
    presence_color = :dodgerblue,
    absence_color = :seagreen4,
    density_alpha = 0.7,
    denisty_line_width = 2,
)
    main = Axis(
        g[2,1],
        xticklabelsvisible = p2 == 5,
        yticklabelsvisible = p1 == 1,
        xticksvisible = p2 == 5,
        yticksvisible = p1 == 1, 
        xlabel = p2 == 5 ? "Predictor $p1" : "",
        ylabel = p1 == 1 ? "Predictor $p2" : "",
    )

    top = Axis(
        g[1,1], 
    )
    hidedecorations!(top)
    hidespines!(top)
    right = Axis(g[2,2])
    hidedecorations!(right)
    hidespines!(right)

    scatter!(
        main, 
        [predictors[p1][i] for i in findall(absences)],
        [predictors[p2][i] for i in findall(absences)],
        color = (absence_color, 0.02),
    )
    scatter!(
        main, 
        [predictors[p1][i] for i in findall(presences)],
        [predictors[p2][i] for i in findall(presences)],
        color = (presence_color, 0.05),
    )

    if p1 == p2 - 1
        density!(top, [predictors[p1][i] for i in findall(presences)], color=(presence_color, density_alpha), strokewidth = denisty_line_width, strokecolor=presence_color)
        density!(top, [predictors[p1][i] for i in findall(absences)], color=(absence_color, density_alpha), strokewidth = denisty_line_width, strokecolor=absence_color)

        density!(right, [predictors[p2][i] for i in findall(presences)], color=(presence_color,density_alpha), 
        strokewidth = denisty_line_width, strokecolor=presence_color, direction=:y)
        density!(right, [predictors[p2][i] for i in findall(absences)], color=(absence_color, density_alpha), strokewidth = denisty_line_width, strokecolor=absence_color, direction=:y)

        colsize!(g, 1, Relative(0.99))
        rowsize!(g, 2, Relative(0.99))


    else
        colsize!(g, 1, Relative(0.8))
        rowsize!(g, 2, Relative(0.8))
    end 
    linkxaxes!(main, top)
    linkyaxes!(main, right)

    colsize!(g, 1, Relative(0.8))
    rowsize!(g, 2, Relative(0.8))

    colgap!(g, 1, 0.01)
    rowgap!(g, 1, 0.01)


    main
end 

function corners(predictors, presence_layer, bgpoints)
    N = min(length(predictors), 5)

    fig = Figure(size=(1200,1200))
    f = GridLayout(fig[1,1])

    mains = Any[nothing for i in 1:N-1, j in 1:N-1]
    for i in 1:N
        mn = []
        for j in (i+1):N
            g = GridLayout(f[j-1,i])
            main = _env_correlation_plot(g, predictors, i,j, presence_layer, bgpoints)
            mains[i,j-1] = main
        end
    end

    for r in eachrow(mains)
        axes = filter(!isnothing, r)
        for i in eachindex(axes)[2:end]
            linkxaxes!(axes[i], axes[i-1])
        end
    end

    for c in eachcol(mains)
        axes = filter(!isnothing, c)
        for i in eachindex(axes)[2:end]
            linkyaxes!(axes[i], axes[i-1])
        end
    end

    for i in 1:N-2
        colgap!(f, i, 0.01)
        rowgap!(f, i, 0.01)

    end

    fig
end 

