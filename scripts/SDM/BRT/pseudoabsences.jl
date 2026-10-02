function generate_pseudoabsences(
    presence_layer;
    min_distance=20.0,
    max_candidate_pas=100_000,
    pa_proportion=1.0
)

    num_pas = Int(floor(pa_proportion*sum(presence_layer)))

    num_possible_pas = sum(presence_layer.indices)
    candidate_pa = copy(presence_layer)
    if num_possible_pas > max_candidate_pas
        candidate_pa = backgroundpoints(pseudoabsencemask(RandomSelection, presence_layer), max_candidate_pas)
    else
        # Every valid cell that is not a presence is a candidate.
        candidate_pa.grid .= .!presence_layer.grid
    end

    candidate_pres = copy(presence_layer)
    candidate_pres.indices[findall(iszero, candidate_pres)] .= 0
    candidate_pres.indices[findall(candidate_pa)] .= 1


    dte = pseudoabsencemask(DistanceToEvent, candidate_pres)
    pa_mask = copy(dte)
    pa_mask.indices[findall(x -> x < min_distance, dte)] .= false

    if !any(pa_mask.indices)
        max_dist = any(dte.indices) ? maximum(dte.grid[dte.indices]) : "n/a (no valid cells)"
        biab_error_stop("No valid cell left for pseudoabsences: none is farther than $min_distance from a presence (max distance found: $max_dist). Reduce the pseudoabsence buffer, enlarge the bounding box, or check that the predictors and water mask overlap the occurrences.")
    end


    bgpoints = backgroundpoints(pa_mask, num_pas)

    es, ns = eastings(bgpoints), northings(bgpoints)
    _pa_coords = [(es[x[2]], ns[x[1]]) for x in findall(isone, bgpoints)]
    
    pa_df = DataFrame(lon=[x[1] for x in _pa_coords], lat=[x[2] for x in _pa_coords])

    return bgpoints, pa_df
end

