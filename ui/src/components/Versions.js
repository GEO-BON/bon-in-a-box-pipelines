import { useEffect, useState } from "react";
import {Spinner} from "./Spinner"

const BonInABoxScriptService = require("bon_in_a_box_script_service");
export const api = new BonInABoxScriptService.DefaultApi();

export default function Versions() {
    let [versions, setVersions] = useState()
    useEffect(() => {
        api.getVersions((error, _, response) => {
            if (response && response.text) setVersions(response.text);
            else if (error) setVersions(error.toString());
            else setVersions(null);
        });
    }, [])

    return <p style={{whiteSpace: "pre-wrap"}}>{versions ? versions : <Spinner />}</p>
}