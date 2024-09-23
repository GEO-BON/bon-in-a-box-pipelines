function _get_wgs84_bbox(transformer, xmin, ymin, xmax, ymax)
    tr, tl, bl, br = (xmax, ymax), (xmin, ymax), (xmin, ymin), (xmax, ymin)
    _new_coords = [transformer(x...) for x in [tr, tl, bl, br]]
    xmin, xmax = extrema([x[1] for x in _new_coords])
    ymin, ymax = extrema([x[2] for x in _new_coords])
    return (left=xmin, right=xmax, bottom=ymin, top=ymax)
end

function _get_occurrence_layer(transformer, template, occurrence_df)
    presence_layer = zeros(template, Bool)
    wgs84_presence_coords = [transformer(r.lon, r.lat) for r in eachrow(occurrence_df)]
    for x in wgs84_presence_coords
        presence_layer[x...] = true
    end
    return presence_layer
end

# hacky, bad even
# this should be a subpipeline that chains loadFromSTAC w/ a simple script to do this
function _get_water_mask(layer_path)
    lc = SDMLayer(layer_path)
    nodata!(lc, isequal(210))
    lc.grid[lc.indices] .= 1
    return lc
end

function get_features_and_labels(predictors, presences, absences)
    locations = [findall(presences)..., findall(absences)...]
    features = Float32.([predictors[i][k] for k in locations, i in eachindex(predictors)])
    labels = [ones(Bool, sum(presences))..., zeros(Bool, sum(absences))...]
    return features, labels
end 

function crossvalidation_split(
    labels;
    test_proportion = 0.2
)
    nt = Int(floor(test_proportion*length(labels)))
    test_idx = Random.shuffle(eachindex(labels))[1:nt]
    train_idx = setdiff(eachindex(labels), test_idx)
    return train_idx, test_idx
end 