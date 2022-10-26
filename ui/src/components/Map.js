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
]).domain([0.001, 1]);

function COGLayer({ url }) {
  const rasterRef = useRef()
  const map = useMap()

  // UseEffect to execute code after map div is inserted
  useEffect(() => {
    console.log("url=" + url)

    parseGeoraster(window.location.origin + url).then((georaster) => {
      if (georaster) {
        console.log("got my raster", georaster)
        rasterRef.current = georaster

        const options = { left: 0, top: 0, right: 4000, bottom: 4000, width: 10, height: 10 };
        georaster.getValues(options).then(values => {
          console.log("clipped values are", values);
        });

        const layer = new GeoRasterLayer({
          attribution: "Planet",
          type: "coglayer",
          georaster: georaster,
          debugLevel: 0,
          resolution: 128,
          pixelValuesToColorFn: (values) => values[0] ? scale(values[0]).hex() : "#ffffff00"
        });
        layer.addTo(map)
        map.fitBounds(layer.getBounds());

      } else {
        console.error("Failed to fetch raster")
      }
    });

    return () => { if (rasterRef.current) map.removeLayer(rasterRef.current) };
  }, [map]);

  return null;
}

export default function Map({ tiff }) {
  return <MapContainer className="map" >
    <TileLayer
      attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
      url="https://{s}.tile.osm.org/{z}/{x}/{y}.png"
    />
    <COGLayer url={tiff} />
  </MapContainer>
}