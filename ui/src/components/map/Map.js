import React, { useEffect, useState } from "react";

import { Marker, MapContainer, TileLayer, GeoJSON, Popup } from "react-leaflet";
import 'leaflet/dist/leaflet.css';
import L from 'leaflet';
import COGLayer from "./COGLayer";
import TiTilerLayer from "./TiTilerLayer";

// This is to make sure leaflet icons show up.
// see https://github.com/PaulLeCam/react-leaflet/issues/453#issuecomment-410450387
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
    iconRetinaUrl: require('leaflet/dist/images/marker-icon-2x.png'),
    iconUrl: require('leaflet/dist/images/marker-icon.png'),
    shadowUrl: require('leaflet/dist/images/marker-shadow.png')
})

function addTiffLayer(url, range, setError) {
  const fullUrl = url.startsWith("http") ? url : window.location.origin + url
  if(fullUrl.startsWith("http://localhost")) {
    // For relative paths on localhost, we cannot use the online tiler. 
    // This will be easy to see since a completely different color map will be used.
    return <COGLayer url={fullUrl} range={range} setError={setError} />
  }

  // There is a bug with georaster that overlaps tiles when using a remote COG.
  // Our workaround is to use TiTiler to serve it as a tile layer instead.
  // see https://matplotlib.org/stable/tutorials/colors/colormaps.html
  return <TiTilerLayer url={fullUrl} range={range} setError={setError} />
}

export default function MapResult({ tiff, range, json, markers }) {
  const [error, setError] = useState()
  const [jsonContent, setJsonContent] = useState()

  useEffect(() => {
    if (json) {
      fetch(json)
        .then((response) => {
          if (response.ok)
            return response.json();
          else
            return Promise.reject("Error " + response.status);

        }).then((result) => {
          setJsonContent(result)
        })
        .catch(error => {
          setError(error)
          setJsonContent(null)
        })
    }
  }, [json])

  if (error)
    return <p className='error'>{error}</p>

  return <MapContainer className="map" center={[0, 0]} zoom={5}>
    <TileLayer
      attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
      url="https://{s}.tile.osm.org/{z}/{x}/{y}.png"
    />

    {markers && markers.map((marker, i) => marker.pos && marker.pos[0] && marker.pos[1] &&
      <Marker key={i} position={marker.pos}>
        <Popup>{marker.popup}</Popup>
      </Marker>
    )}

    {jsonContent &&
      <GeoJSON data={jsonContent}
        eventHandlers={{
          add: (e) => e.target._map.fitBounds(e.target.getBounds())
        }}
      />
    }

    {tiff && addTiffLayer(tiff, range, setError)}
  </MapContainer>
}