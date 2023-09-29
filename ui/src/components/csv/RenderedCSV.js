import React, { useEffect, useState } from 'react'
import CsvToHtmlTable, {parseCsvToRowsAndColumn} from './CsvToHtmlTable.jsx'
import MapResult from '../map/Map';
import { Spinner } from '../Spinner.js';

/**
 * Properties
 * - url: source of content
 * - delimiter: used to parse the CSV file
 */
function RenderedCSV({url, delimiter}) {
    const [asMap, setAsMap] = useState(false)

    return <>
        <button onClick={() => setAsMap(b => !b)}>{asMap ? "View in table" : "View on map"}</button>
        {asMap ? <CsvToMap url={url} delimiter={delimiter} />
            : <CsvToTable url={url} delimiter={delimiter} />}
    </>
}

function CsvToTable({url, delimiter}) {
    const [error, setError] = useState()
    const [data, setData] = useState(null)
    const [partial, setPartial] = useState(false)

    useEffect(() => {
        const maxLength = 1024*6;

        var xhr = new XMLHttpRequest();
        xhr.open("get", url);
        xhr.setRequestHeader("Range", "bytes=0-" + maxLength);
        xhr.onreadystatechange = function () {
            if (xhr.readyState === 4) {
                if(xhr.status === 200 || xhr.status === 206) {
                    let responseLength = new TextEncoder().encode(xhr.responseText).length
    
                    let csv = xhr.responseText
                    if(responseLength >= maxLength){
                        // Remove last line (99% chances it's incomplete...)
                        csv = csv.substring(0, csv.lastIndexOf("\n"))
                        setPartial(true)
                    }
    
                    setData(csv)
                } else {
                    setError(xhr.statusText ? xhr.statusText : "Error " + xhr.status)
                }
            }
        };
        xhr.send();
    }, [url]);

    if (data || error)
        return <>
            {error && <p className='error'>{error}</p>}
            {data && <CsvToHtmlTable data={data} csvDelimiter={delimiter} />}
            {partial && <p>Displaying partial data. <a href={url}>Download full csv file</a> for complete data.</p>}
        </>
    else
        return <Spinner />
}

function CsvToMap({url, delimiter}) {
    const [error, setError] = useState()
    const [data, setData] = useState(null)

    function stripQuotes(string) {
        return string && string.startsWith('"') && string.endsWith('"') ? string.slice(1, -1) : string
    }

    function readCoordinates(data, delimiter){
        const rowsWithColumns = parseCsvToRowsAndColumn(data, delimiter)
        const headerRow = rowsWithColumns.splice(0, 1)[0];

        const latRegEx = new RegExp('lat(itude)?', 'i')
        const latColumn = headerRow.findIndex(h => latRegEx.test(h))

        const lonRegEx = new RegExp('lon(gitude)?', 'i')
        const lonColumn = headerRow.findIndex(h => lonRegEx.test(h))

        if(latColumn === -1 || lonColumn === -1) {
            setError("Both latitude and longitude columns must be present to display on a map.")
            return null
        }
        
        return rowsWithColumns.map(row =>
        ({
            pos: [row[latColumn], row[lonColumn]],
            popup: <>
                {headerRow.map((header, i) => header &&
                    <div key={header}>
                        {stripQuotes(header)}: {stripQuotes(row[i])}
                    </div>)}
            </>
        }))
    }

    useEffect(() => {
        fetch(url)
            .then((response) => {
                if (response.ok)
                    return response.text();
                else
                    return Promise.reject("Error " + response.status);

            }).then((result) => {
                setData(result)

            }).catch(error => {
                setError(error)
            })

    }, [url]);

    if (data || error)
        return <>
            {error && <p className='error'>{error}</p>}
            {!error && data && <MapResult markers={readCoordinates(data, delimiter)} />}
        </>
    else
        return <Spinner />
}

export default RenderedCSV