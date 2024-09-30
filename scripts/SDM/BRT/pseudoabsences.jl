function generate_pseudoabsences(
    presence_layer,
    transformer;
    min_distance=20.0,
    num_candidate_pas=100_000,
    num_pas=sum(presence_layer)
)
    candidate_pa = backgroundpoints(pseudoabsencemask(RandomSelection, presence_layer), num_candidate_pas)

    candidate_pres = copy(presence_layer)
    candidate_pres.indices[findall(iszero, candidate_pres)] .= 0
    candidate_pres.indices[findall(candidate_pa)] .= 1

    dte = pseudoabsencemask(DistanceToEvent, candidate_pres)
    pa_mask = copy(dte)
    pa_mask.indices[findall(x -> x < min_distance, dte)] .= false

    bgpoints = backgroundpoints(pa_mask, num_pas)

    es, ns = eastings(bgpoints), northings(bgpoints)
    _wgs84_pa_coords = [transformer(es[x[2]], ns[x[1]]) for x in findall(isone, bgpoints)]
    pa_df = DataFrame(lon=[x[1] for x in _wgs84_pa_coords], lat=[x[2] for x in _wgs84_pa_coords])

    return bgpoints, pa_df
end

