import { useState, useEffect } from 'react';
import { Handle, Position } from 'react-flow-renderer/nocss';


const yaml = require('js-yaml');
const BonInABoxScriptService = require('bon_in_a_box_script_service');
const api = new BonInABoxScriptService.DefaultApi();

export default function IONode({ data }) {
  const [descriptionFileLocation] = useState(data.descriptionFile);
  const [metadata, setMetadata] = useState(null);

  useEffect(() => {
    if (descriptionFileLocation) {
      var callback = function (error, data, response) {
        if (error) {
          console.error("Loading " + descriptionFileLocation + ": " + error.toString())
        } else {
          setMetadata(yaml.load(data))
        }
      };

      api.getScriptInfo(descriptionFileLocation, callback);
    }
  }, [descriptionFileLocation])


  return (metadata &&
    <table className='ioNode'>
      <tr>
        <td className='inputs'>
          {metadata.inputs && Object.entries(metadata.inputs).map(([key, desc]) => {
            return <div key={key}>
              <Handle id={key} type="target" position={Position.Left} />
              <span>{desc.label ? desc.label : key}</span>
            </div>
          })}
        </td>
        <td className='name'>
          {metadata.script}
        </td>
        <td className='outputs'>
        {metadata.outputs && Object.entries(metadata.outputs).map(([key, desc]) => {
            return <div key={key}>
              <span>{desc.label ? desc.label : key}</span>
              <Handle id={key} type="source" position={Position.Right} />
            </div>
          })}
        </td>
      </tr>
    </table>
  );
}