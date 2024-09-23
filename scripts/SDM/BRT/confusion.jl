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
    prauc = auc(tpr.(M), ppv.(M))  
    τ = T[last(findmax(vec(mcc.(M))))]

    return Dict(
        :rocauc => rocauc,
        :prauc => prauc,
        :mcc => mcc.(M),
        :threshold => τ
    ), M
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