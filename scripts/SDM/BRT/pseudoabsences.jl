function generate_pseudoabsences(
    presence_layer;
    min_distance=20.0,
    max_candidate_pas=100_000,
    pa_proportion=1.0
)
    num_pas = floor(Int, pa_proportion * sum(presence_layer))

    candidates = pseudoabsencemask(RandomSelection, presence_layer)
    if sum(candidates) > max_candidate_pas
        candidates = backgroundpoints(candidates, max_candidate_pas; replace=false)
    end

    search_area = nodata(presence_layer | candidates, false)
    search_layer = mask(presence_layer, search_area)

    pa_mask = nodata(pseudoabsencemask(WithoutRadius, search_layer; distance=min_distance), false)

    if iszero(length(pa_mask))
        biab_error_stop("No valid cell left for pseudoabsences....")
    end

    bgpoints = backgroundpoints(pa_mask, min(num_pas, length(pa_mask)); replace=false)

    pa_coords = lonlat(nodata(bgpoints, false))
    pa_df = DataFrame(lon=first.(pa_coords), lat=last.(pa_coords))

    return bgpoints, pa_df
end