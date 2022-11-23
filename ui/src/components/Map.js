import React, { useEffect, useRef } from "react";
import parseGeoraster from "georaster";
import GeoRasterLayer from "georaster-layer-for-leaflet";
import chroma from "chroma-js";
import { MapContainer, TileLayer, useMap } from "react-leaflet";
import 'leaflet/dist/leaflet.css';
import {createRangeLegendControl} from "./Legend"

const scaleColors = [
  "#E5E5E5",
  "#36648B",
  "#5CACEE",
  "#63B8FF",
  "#FFD700",
  "#FF0000",
  "#8B0000",
]
const scale = chroma.scale(scaleColors);

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

function nextPowerRange({ min, max }) {
  if (min < 0) { // probably a something like [-1,1], [-256,256], etc.
    // This is slightly inexact because normally singed range should be like [-256,255], but is good enough for visualisation purpose.
    let maxAbs = Math.max(-min, max)
    let power = 1;
    while (power < maxAbs)
      power *= 2;

    return { min: -power, max: power }

  } else { // probably something like [0,1], [0,255], etc.
    let power = 1;
    while (power - 1 < max)
      power *= 2;

    power -= 1
    return { min: 0, max: power }
  }
}
// Tests
// console.log(standardRange({ min: -0.1, max: 0.5 }))
// console.log(standardRange({ min: -1, max: 1 }))
// console.log(standardRange({ min: -1.1, max: 0.5 }))
// console.log(standardRange({ min: -0.1, max: 1.5 }))
// console.log(standardRange({ min: -100, max: 120 }))
// console.log(standardRange({ min: 0, max: 0.9 }))
// console.log(standardRange({ min: 2, max: 200 }))

function COGLayer({ url, range }) {
  const rasterRef = useRef()
  const map = useMap()

  // UseEffect to execute code after map div is inserted
  useEffect(() => {
    if (!map || !url)
      return

    let layer
    let legend

    const fullUrl = url.startsWith("http") ? url : window.location.origin + url
    parseGeoraster(fullUrl).then((georaster) => {
      if (georaster) {
        rasterRef.current = georaster 

        // To get an idea of min and max, reduce the whole image to 100x100
        const options = { left: 0, top: 0, right: georaster.width, bottom: georaster.height, width: 100, height: 100 };

        const addLayer = (min, max) => {
          const colorTransform = scale.domain([min, max])

          layer = new GeoRasterLayer({
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

          legend = createRangeLegendControl(min, max, scaleColors)
          legend.addTo(map);
        }

        if (range) {
          console.log("Using prescribed range", range)
          addLayer(range[0], range[1])

        } else { // Find out range that fits
          georaster.getValues(options).then(values => {

            // Accessing index 0 since the 2d array is in another array, for some reason...
            const thumbnailRange = minMax2d(values[0])
            const standardRange = nextPowerRange(thumbnailRange)

            // We use standard range if if holds more than hald of the thumbnail values
            const chosenRange = thumbnailRange.max - thumbnailRange.min < (standardRange.max - standardRange.min) / 2
              ? { min: Math.floor(thumbnailRange.min), max: Math.ceil(thumbnailRange.max) }
              : standardRange

            // const range = VarianceRange(values[0])
            console.log("Using calculated range:", chosenRange)
            addLayer(Math.floor(chosenRange.min), Math.ceil(chosenRange.max))
          })
        } 

      } else {
        console.error("Failed to fetch raster")
      }
    })

    return () => {
      if (layer)
        layer.remove()

      if(legend)
        legend.remove()
    };
  }, [map, range, url]);

  return null;
}

export default function Map({ tiff, range }) {
  return <MapContainer className="map" >
    <TileLayer
      attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
      url="https://{s}.tile.osm.org/{z}/{x}/{y}.png"
    />
    <COGLayer url={tiff} range={range} />
  </MapContainer>
}