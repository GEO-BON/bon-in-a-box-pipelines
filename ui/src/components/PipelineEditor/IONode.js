import { useState, useEffect } from 'react';
import { Handle, Position } from 'react-flow-renderer/nocss';


const yaml = require('js-yaml');
const BonInABoxScriptService = require('bon_in_a_box_script_service');
const api = new BonInABoxScriptService.DefaultApi();

// props content, see https://reactflow.dev/docs/api/nodes/custom-nodes/#passed-prop-types
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
    <table className='ioNode'><tbody>
      <tr>
        <td className='inputs'>
          {metadata.inputs && Object.entries(metadata.inputs).map(([inputName, desc]) => {
            return <ScriptInput key={inputName} inputName={inputName} desc={desc} setToolTip={data.setToolTip} />
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
    </tbody></table>
  );
}

function ScriptInput(props) {
  function setToolTip() {
    props.setToolTip(<>
      {props.desc.type && <>{props.desc.type} <br /></>}
      {props.desc.description && <>{props.desc.description} <br /></>}
      {props.desc.example && <>Example: {props.desc.example}</>}
    </>)
  }

  function clearToolTip() {
    props.setToolTip(null)
  }

  return <div onMouseEnter={setToolTip} onMouseLeave={clearToolTip}>
    <Handle id={props.inputName} type="target" position={Position.Left} />
    <span>{props.desc.label ? props.desc.label : props.inputName}</span>
  </div>
}