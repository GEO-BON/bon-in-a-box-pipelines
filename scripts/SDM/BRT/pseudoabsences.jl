
function generate_pseudoabsences(
    presence_layer, 
    transformer;
    min_distance = 20.,
    num_candidate_local_bgs = 100_000,
    num_close_pa = sum(presence_layer),
    num_distant_pa = sum(presence_layer)
)
  
    # ===================================================
    # Generate outside SRE

    within_sre_mask = pseudoabsencemask(SurfaceRangeEnvelope, presence_layer)

    outside_sre_mask =.!within_sre_mask
    outside_sre_mask.grid[findall(presence_layer)] .= 0

    # gets distant PAs
    distant_pa = backgroundpoints(outside_sre_mask, num_distant_pa)

    # ===================================================
    # Within SRE

    # sets everything outside sre to nodata
    local_pres = copy(presence_layer)
    local_pres.indices[findall(outside_sre_mask)] .= 0
    local_pres.indices[findall(presence_layer)] .= 1

    # There are still too many candidate cells to efficiently compute distance to closest presence, so we a 100k at random 
    cand_bg = backgroundpoints(pseudoabsencemask(RandomSelection, local_pres), num_candidate_local_bgs)

    # drop non-candidate 0s
    local_pres.indices[findall(iszero, local_pres)] .= 0
    local_pres.indices[findall(cand_bg)] .= 1

    dte = pseudoabsencemask(DistanceToEvent, local_pres)

    # add minimum distance from presence buff
    pa_mask = copy(dte)
    pa_mask.indices[findall(x-> x < min_distance, dte)]  .= false

    closer_pa = backgroundpoints(pa_mask, num_close_pa)

    bgpoints = copy(distant_pa) 
    bgpoints.grid[findall(closer_pa)] .= 1

    es, ns = eastings(bgpoints), northings(bgpoints)
    _wgs84_pa_coords = [transformer(es[x[2]], ns[x[1]]) for x in findall(isone, bgpoints)]
    pa_df = DataFrame(lon=[x[1] for x in _wgs84_pa_coords], lat=[x[2] for x in _wgs84_pa_coords])

    return bgpoints, pa_df
end
