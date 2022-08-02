import React, { useEffect, useRef } from 'react'
import chroma from "chroma-js";
import * as L from "leaflet";

const scale = chroma.scale([
    "#E5E5E5",
    "#36648B",
    "#5CACEE",
    "#63B8FF",
    "#FFD700",
    "#FF0000",
    "#8B0000",
])

function RenderedMap(props) {
    const mapRef = useRef(null);

    // UseEffect to execute code after map div is inserted
    useEffect(() => {
        var parse_georaster = require("georaster");
        var GeoRasterLayer = require("georaster-layer-for-leaflet");

        // initalize leaflet map
        if (!mapRef.current) {
            mapRef.current = L.map('map').setView([0, 0], 5);

            // add OpenStreetMap basemap
            L.tileLayer('https://{s}.tile.osm.org/{z}/{x}/{y}.png', {
                attribution: '&copy; <a href="http://osm.org/copyright">OpenStreetMap</a> contributors'
            }).addTo(mapRef.current);
        }

        var url_to_geotiff_file = props.tiff;
        console.log("reading geotiff at " + url_to_geotiff_file)

        fetch(url_to_geotiff_file)
            .then(response => response.arrayBuffer())
            .then(arrayBuffer => {
                parse_georaster(arrayBuffer).then(georaster => {
                    console.log("Using min " + georaster.mins[0])
                    console.log("Using max " + georaster.maxs[0])
                    const colorDomain = scale.domain([georaster.mins[0], georaster.maxs[0]]);

                    /*
                        GeoRasterLayer is an extension of GridLayer,
                        which means can use GridLayer options like opacity.
              
                        Just make sure to include the georaster option!
              
                        Optionally set the pixelValuesToColorFn function option to customize
                        how values for a pixel are translated to a color.
              
                        http://leafletjs.com/reference-1.2.0.html#gridlayer
                    */
                    var layer = new GeoRasterLayer({
                        georaster: georaster,
                        opacity: 0.6,
                        resolution: 320, // optional parameter for adjusting display resolution
                        pixelValuesToColorFn: (values) => values[0] ? colorDomain(values[0]).hex() : "#ffffff00"
                    });
                    layer.addTo(mapRef.current);

                    mapRef.current.fitBounds(layer.getBounds());
                });
            });
    })


    return (
        <>
            <link rel="stylesheet" href="https://unpkg.com/leaflet@1.0.3/dist/leaflet.css" />
            <div id="map" className="map"></div>
        </>
    )
}

export default RenderedMap