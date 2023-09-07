import React, { useEffect, useState } from "react";

import { TileLayer, useMap } from "react-leaflet";
import 'leaflet/dist/leaflet.css';
import { createRangeLegendControl } from "./Legend"
import L from 'leaflet';
import { extractLegend } from "../../utils/ColorMapping";

// const TILER_URL = 'https://titiler.xyz/cog' // A generic tiler available on the web
const TILER_URL = window.location.origin + "/tiler" // A tiler in the internal docker network
const COLORMAP_NAME = 'hot' // see available in ColorMapping

function fetchStats(url) {
  return fetch(`${TILER_URL}/cog/statistics?url=${url}`)
    .then(response => {
      if (response.ok)
        return response.json()
      else
        return Promise.reject('Failed to get statistics')
    })
    .then(statArray => {
      const values = Object.values(statArray)
      if (values.length > 0) {
        return values[0]
      }
      else
        return Promise.reject('Statistics array is empty')
    })
}

function fetchBounds(url) {
  return fetch(`${TILER_URL}/cog/bounds?url=${url}`)
    .then(response => {
      if (!response.ok) return Promise.reject('Failed to get bounds')
      return response.json()
    })
    .then(json => {
      if (!json.bounds) return Promise.reject('Bounds result is empty')
      return json.bounds
    })
}

export default function TiTilerLayer({ url, range, setError }) {
  const [tileLayerUrl, setTileLayerUrl] = useState()
  const [bounds, setBounds] = useState(null)
  const map = useMap()

  useEffect(() => {
    let legend

    const addLayer = (min, max) => {
      fetchBounds(url)
        .then(bounds => {
          let corner1 = L.latLng(bounds[1], bounds[0])
          let corner2 = L.latLng(bounds[3], bounds[2])
          let leafletBounds = L.latLngBounds(corner1, corner2)
          setBounds(leafletBounds)
          map.fitBounds(leafletBounds)
        })
        .catch(error => setError(error.message))
        .finally(() => { // Ideally we have bounds first so we don't fetch tiles outside, but it's not mandatory.
          const tiler = `${TILER_URL}/cog/tiles/{z}/{x}/{y}`;
          const rescale = `${min},${max}`;
          const params = new URLSearchParams({
            /*assets: selectedLayerAssetName,*/
            colormap_name: COLORMAP_NAME
          }).toString();

          setTileLayerUrl(`${tiler}?url=${url}&rescale=${rescale}&${params}`)
        })

      legend = createRangeLegendControl(min, max, extractLegend(COLORMAP_NAME, 6))
      legend.addTo(map);
    }

    if(range) {
      addLayer(range[0], range[1])
    } else {
      fetchStats(url)
        .then(statistics => {
          addLayer(statistics.percentile_2, statistics.percentile_98)
        })
        .catch(error => setError(error.message))
    }

    return () => {
      if (legend)
        legend.remove()
    };
  }, [url, map, range, setError])

  return tileLayerUrl && 
    <TileLayer key={tileLayerUrl /*https://stackoverflow.com/a/72552510/3519951*/} url={tileLayerUrl} opacity={0.7} bounds={bounds} />
}