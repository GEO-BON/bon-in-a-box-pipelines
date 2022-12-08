import React, { useEffect, useState } from "react";

import { TileLayer, useMap } from "react-leaflet";
import 'leaflet/dist/leaflet.css';
import { createRangeLegendControl } from "./Legend"
import L from 'leaflet';
import { extractLegend } from "../../utils/ColorMapping";

const TILER_URL = 'https://tiler.biodiversite-quebec.ca/cog'
const COLORMAP_NAME = "inferno" // see available in ColorMapping

function fetchStats(url) {
  return fetch(`${TILER_URL}/statistics?url=${url}`)
    .then(response => {
      if (response.ok)
        return response.json()
      else
        return Promise.reject(new Error('Failed to get statistics'))
    })
    .then(statArray => {
      if (statArray[1])
        return statArray[1]
      else
        return Promise.reject(new Error('Statistics array is empty'))
    })
}

function fetchBounds(url) {
  return fetch(`${TILER_URL}/bounds?url=${url}`)
    .then(response => {
      if (!response.ok) throw 'Failed to get bounds'
      return response.json()
    })
    .then(json => {
      if (!json.bounds) throw 'Bounds result is empty'
      return json.bounds
    })
}

export default function TiTilerLayer({ url, range }) {
  const [tileLayerUrl, setTileLayerUrl] = useState()
  const map = useMap()

  useEffect(() => {
    let legend

    const addLayer = (min, max) => {
      const tiler = `${TILER_URL}/tiles/{z}/{x}/{y}`;
      const rescale = `${min},${max}`;
      const params = new URLSearchParams({
        /*assets: selectedLayerAssetName,*/
        colormap_name: COLORMAP_NAME
      }).toString();

      setTileLayerUrl(`${tiler}?url=${url}&rescale=${rescale}&${params}`)

      legend = createRangeLegendControl(min, max, extractLegend(COLORMAP_NAME, 6))
      legend.addTo(map);

      fetchBounds(url).then(bounds => {
        let corner1 = L.latLng(bounds[1], bounds[0])
        let corner2 = L.latLng(bounds[3], bounds[2])
        map.fitBounds(L.latLngBounds(corner1, corner2))
      })
    }

    if(range) {
      addLayer(range.min, range.max)
    } else {
      fetchStats(url)
        .then(statistics => {
          /*let data = []; 
          const selectedLayerAssetName = ""
          if (Object.keys(layerInfo).includes("data")) {
            data = layerInfo.data[1];
          } else {
            data = layerInfo[selectedLayerAssetName][1];
          }*/

          addLayer(statistics.percentile_2, statistics.percentile_98)
        })
        .catch(err => console.error(err))
    }

    return () => {
      if (legend)
        legend.remove()
    };
  }, [url])

  return tileLayerUrl && <TileLayer url={tileLayerUrl} /*eventHandlers={{
    add: (e) => console.log(e)
  }}*/ />
}