struct ConfusionMatrix{T <: Number}
    tp::T
    tn::T
    fp::T
    fn::T
end

function ConfusionMatrix(pred::Vector{Bool}, truth::Vector{Bool})
    tp = sum(pred .& truth)
    tn = sum(.!pred .& .!truth)
    fp = sum(pred .& .!truth)
    fn = sum(.!pred .& truth)
    return ConfusionMatrix(tp, tn, fp, fn)
end

function ConfusionMatrix(pred::Vector{T}, truth::Vector{Bool}, τ::T) where {T <: Number}
    return ConfusionMatrix(convert(Vector{Bool}, pred .>= τ), truth)
end

function ConfusionMatrix(pred::Vector{T}, truth::Vector{Bool}) where {T <: Number}
    return ConfusionMatrix(pred, truth, 0.5)
end

function ConfusionMatrix(pred::BitVector, args...)
    return ConfusionMatrix(convert(Vector{Bool}, pred), args...)
end

function ConfusionMatrix(pred::BitVector, truth::BitVector, args...)
    return ConfusionMatrix(
        convert(Vector{Bool}, pred),
        convert(Vector{Bool}, truth),
        args...,
    )
end

function Base.Matrix(c::ConfusionMatrix)
    return [c.tp c.fp; c.fn c.tn]
end

Base.zero(ConfusionMatrix) = ConfusionMatrix(0, 0, 0, 0)


function compute_fit_stats(model, features, labels, test_idx)
    T = LinRange(0.0, 1.0, 250)
    M = zeros(ConfusionMatrix, length(T))
    test_preds = EvoTrees.predict(model, features[test_idx, :])
    for i in eachindex(T)
        M[i] = ConfusionMatrix(test_preds[:, 1], labels[test_idx], Float32(T[i]))
    end
    rocauc = auc(fpr.(M), tpr.(M)) 
    precision = ppv.(M)
    precision[isnan.(precision)] .= 1.0 # no positive prediction at this threshold: precision is undefined, 1 by convention
    prauc = auc(tpr.(M), precision)
    thresh_idx = last(findmax(vec(mcc.(M))))
    τ = T[thresh_idx]

    return Dict(
        :rocauc => rocauc,
        :prauc => prauc,
        :mcc => mcc(M[thresh_idx]),
        :threshold => τ
    ), M
end 

# Heuristic checks; each message is a plain-language sentence followed by a technical one.
function fit_stats_warnings(fit_stats, confusion_matrices)
    warnings = String[]
    add!(plain, technical) = push!(warnings, "$plain $technical")
    r(x) = round(x; digits=2)

    rocauc, prauc, mcc_val, τ = fit_stats[:rocauc], fit_stats[:prauc], fit_stats[:mcc], fit_stats[:threshold]

    # tp + fn and fp + tn do not depend on the threshold.
    M = first(confusion_matrices)
    n_pos, n_neg = M.tp + M.fn, M.fp + M.tn
    baseline = prevalence(M)

    if !all(isfinite, (rocauc, prauc, mcc_val, τ))
        add!("Some performance scores could not be computed, so the model could not be properly evaluated.",
            "At least one of ROC AUC, PR AUC, MCC or threshold is NaN or infinite, usually because the test set lacks presences or absences.")
    end

    if n_pos < 10 || n_neg < 10
        add!("The data used to test the model is very small ($n_pos presences and $n_neg absences), so the scores below are unreliable and may change a lot between runs.",
            "With so few test points the ROC AUC, PR AUC and MCC have very wide confidence intervals, and the MCC-maximizing threshold is optimistically biased since it is selected on the same test set.")
    end

    if rocauc < 0.5
        add!("The model ranks locations worse than random guessing: places where the species was observed tend to score lower than places where it was not.",
            "ROC AUC = $(r(rocauc)) < 0.5, i.e. the score ordering is inverted relative to the labels.")
    elseif rocauc < 0.7
        add!("The model is only weakly able to tell where the species is present from where it is absent.",
            "ROC AUC = $(r(rocauc)) is below the 0.7 usually required for acceptable discrimination.")
    end

    if prauc < baseline
        add!("Among the locations the model flags as suitable, the species is found no more often than by random picking.",
            "PR AUC = $(r(prauc)) is below the no-skill baseline, which equals the test prevalence ($(r(baseline))).")
    end

    if mcc_val <= 0
        add!("At the chosen cut-off, the model's presence/absence predictions are no better than chance.",
            "MCC = $(r(mcc_val)) ≤ 0 at the MCC-maximizing threshold.")
    elseif mcc_val < 0.3
        add!("At the chosen cut-off, the model's presence/absence predictions agree only weakly with the observations.",
            "MCC = $(r(mcc_val)) < 0.3 at the MCC-maximizing threshold.")
    end

    if rocauc < 0.5 && (mcc_val >= 0.3 || prauc > baseline)
        add!("The performance scores contradict each other (one says worse than random, others say better), so none of them should be trusted as is.",
            "ROC AUC < 0.5 while MCC = $(r(mcc_val)) and PR AUC = $(r(prauc)) (baseline $(r(baseline))). Typical causes are a small test set, predictions concentrated in a narrow part of the [0, 1] threshold grid, or predictions outside [0, 1].")
    end

    if τ < 0.05 || τ > 0.95
        add!("The cut-off that turns the model's scores into presence/absence is extreme ($(r(τ))), which means the scores are squeezed into a very narrow range.",
            "The MCC-maximizing threshold is at $(r(τ)) on a uniform [0, 1] grid of 250 points, which suggests poorly calibrated predictions and a coarse effective threshold resolution.")
    end

    return warnings
end

tpr(M::ConfusionMatrix) = M.tp / (M.tp + M.fn)
tnr(M::ConfusionMatrix) = M.tn / (M.tn + M.fp)
ppv(M::ConfusionMatrix) = M.tp / (M.tp + M.fp)
npv(M::ConfusionMatrix) = M.tn / (M.tn + M.fn)
fnr(M::ConfusionMatrix) = M.fn / (M.fn + M.tp)
fpr(M::ConfusionMatrix) = M.fp / (M.fp + M.tn)
fdir(M::ConfusionMatrix) = M.fp / (M.fp + M.tp)
fomr(M::ConfusionMatrix) = M.fn / (M.fn + M.tn)
plr(M::ConfusionMatrix) = tpr(M) / fpr(M)
nlr(M::ConfusionMatrix) = fnr(M) / tnr(M)
accuracy(M::ConfusionMatrix) = (M.tp + M.tn) / (M.tp + M.tn + M.fp + M.fn)
balanced(M::ConfusionMatrix) = (tpr(M) + tnr(M)) * 0.5
f1(M::ConfusionMatrix) = 2 * (ppv(M) * tpr(M)) / (ppv(M) + tpr(M))
trueskill(M::ConfusionMatrix) = tpr(M) + tnr(M) - 1.0
markedness(M::ConfusionMatrix) = ppv(M) + npv(M) - 1.0
dor(M::ConfusionMatrix) = plr(M) / nlr(M)
prevalence(M::ConfusionMatrix) = (M.tp + M.fn) / (M.tp + M.fp + M.tn + M.fn)

function κ(M::ConfusionMatrix)
    return 2.0 * (M.tp * M.tn - M.fn * M.fp) /
           ((M.tp + M.fp) * (M.fp + M.tn) + (M.tp + M.fn) * (M.fn + M.tn))
end

function mcc(M::ConfusionMatrix)
    ret =
        (M.tp * M.tn - M.fp * M.fn) /
        sqrt((M.tp + M.fp) * (M.tp + M.fn) * (M.tn + M.fp) * (M.tn + M.fn))
    return isnan(ret) ? 0.0 : ret
end

function auc(x::Array{T}, y::Array{T}) where {T <: Number}
    S = zero(Float64)
    for i in 2:length(x)
        S += (x[i] - x[i - 1]) * (y[i] + y[i - 1]) * 0.5
    end
    return .-S
end

function ci(C::Vector{ConfusionMatrix}, f)
    v = f.(C)
    return 1.96 * std(v) / sqrt(length(C))
end

ci(C::Vector{ConfusionMatrix}) = ci(C, mcc)

crossentropyloss(y, p) = mean(.-(y .* log.(p) .+ (1.0 .- y) .* log.( 1.0 .- p)))