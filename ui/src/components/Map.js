import React, { useEffect, useRef } from "react";
import parseGeoraster from "georaster";
import GeoRasterLayer from "georaster-layer-for-leaflet";
import chroma from "chroma-js";
import { MapContainer, TileLayer, useMap } from "react-leaflet";
import 'leaflet/dist/leaflet.css';


const scale = chroma.scale([
  "#E5E5E5",
  "#36648B",
  "#5CACEE",
  "#63B8FF",
  "#FFD700",
  "#FF0000",
  "#8B0000",
]);

function COGLayer({ url, range }) {
  const rasterRef = useRef()
  const map = useMap()

  // UseEffect to execute code after map div is inserted
  useEffect(() => {
    if(!map || !range || !url)
      return

    parseGeoraster(window.location.origin + url).then((georaster) => {
      if (georaster) {
        rasterRef.current = georaster

        // Uncomment to debug values in the geotiff
        /*const options = { left: 0, top: 0, right: 4000, bottom: 4000, width: 10, height: 10 };
        georaster.getValues(options).then(values => {
          console.log("clipped values are", values);
        });*/

        const colorTransform = scale.domain([range[0], range[1]])

        const layer = new GeoRasterLayer({
          attribution: "Planet",
          type: "coglayer",
          georaster: georaster,
          debugLevel: 0,
          resolution: 128,
          pixelValuesToColorFn: (values) => values[0] ? colorTransform(values[0]).hex() : "#ffffff00"
        });
        layer.addTo(map)
        map.fitBounds(layer.getBounds());

      } else {
        console.error("Failed to fetch raster")
      }
    });

    return () => {
      if (rasterRef.current) {
        map.removeLayer(rasterRef.current)
        rasterRef.current = null
      }
    };
  }, [map, range, url]);

  return null;
}

export default function Map({ tiff, range }) {
  console.log("Tiff range=",range)

  return <MapContainer className="map" >
    <TileLayer
      attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
      url="https://{s}.tile.osm.org/{z}/{x}/{y}.png"
    />
    <COGLayer url={tiff} range={range} />
  </MapContainer>
}