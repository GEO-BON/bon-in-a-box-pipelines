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

function minMax2d(array2d) {
  var min = Number.MAX_VALUE;
  var max = Number.MIN_VALUE;
  array2d.forEach(array1d => {
    array1d.forEach(v => {
      min = Math.min(v, min)
      max = Math.max(v, max)
    })
  });

  return { min, max };
}

function standardRange({ min, max }) {
  console.log("Range in thumbnail:", min, max)
  if (min < 0) { // probably a something like [-1,1], [-256,256], etc.
    // This is slightly inexact because normally singed range should be like [-256,255], but is good enough for visualisation purpose.
    let maxAbs = Math.max(-min, max)
    let power = 1;
    while (power < maxAbs)
      power *= 2;

    console.log("Estimated range:", -power, power)
    return { min: -power, max: power }

  } else { // probably something like [0,1], [0,255], etc.
    let power = 1;
    while (power - 1 < max)
      power *= 2;

    power -= 1
    console.log("Estimated range:", 0, power)
    return { min: 0, max: power }
  }
}
// Tests
// standardRange({ min: -0.1, max: 0.5 })
// standardRange({ min: -1, max: 1 })
// standardRange({ min: -1.1, max: 0.5 })
// standardRange({ min: -0.1, max: 1.5 })
// standardRange({ min: -100, max: 120 })
// standardRange({ min: 0, max: 0.9 })
// standardRange({ min: 2, max: 200 })

function COGLayer({ url, range }) {
  const rasterRef = useRef()
  const map = useMap()

  // UseEffect to execute code after map div is inserted
  useEffect(() => {
    if (!map || !url)
      return

    const fullUrl = window.location.origin + url
    parseGeoraster(fullUrl).then((georaster) => {
      if (georaster) {
        rasterRef.current = georaster

        // To get an idea of min and max, reduce the whole image to 100x100
        const options = { left: 0, top: 0, right: georaster.width, bottom: georaster.height, width: 1000, height: 1000 };
        
        georaster.getValues(options).then(values => {
          var colorTransform
          if (range) {
            console.log("Using prescribed range", range)
            colorTransform = scale.domain([range[0], range[1]])
          } else {
            // Accessing index 0 since the 2d array is in another array, for some reason...
            const range = standardRange(minMax2d(values[0]))
            colorTransform = scale.domain([range.min, range.max])
          }

          const layer = new GeoRasterLayer({
            attribution: "Planet",
            type: "coglayer",
            georaster: georaster,
            debugLevel: 0,
            opacity: 0.7,
            resolution: 128,
            pixelValuesToColorFn: (values) => values[0] ? colorTransform(values[0]).hex() : "#ffffff00"
          });
          layer.addTo(map)
          map.fitBounds(layer.getBounds());
        })

      } else {
        console.error("Failed to fetch raster")
      }
    })

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