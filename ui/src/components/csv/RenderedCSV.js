import React, { useEffect, useState } from 'react'
import spinner from '../../img/spinner.svg';
import CsvToHtmlTable from './CsvToHtmlTable.jsx'

/**
 * Properties
 * - url: source of content
 * - delimiter: used to parse the CSV file
 */
function RenderedCSV(props) {
    const [data, setData] = useState(null)
    const [partial, setPartial] = useState(false)

    useEffect(() => {
        const maxLength = 2048;

        var xhr = new XMLHttpRequest();
        xhr.open("get", props.url);
        xhr.setRequestHeader("Range", "bytes=0-" + maxLength);
        xhr.onreadystatechange = function () {
            if (xhr.readyState === 4) {
                let responseLength = new TextEncoder().encode(xhr.responseText).length

                let csv = xhr.responseText
                if(responseLength >= maxLength){
                    // Remove last line (99% chances it's incomplete...)
                    csv = csv.substring(0, csv.lastIndexOf("\n"))
                    setPartial(true)
                }

                setData(csv)
            }
        };
        xhr.send();
    }, [props.url]);

    if (data)
        return <>
            <CsvToHtmlTable data={data} csvDelimiter={props.delimiter} />
            {partial && <p>Displaying partial data. <a href={props.url}>Download full csv file</a> for complete data.</p>}
        </>
    else
        return <img src={spinner} className="spinner" alt="Spinner" />
}

export default RenderedCSV