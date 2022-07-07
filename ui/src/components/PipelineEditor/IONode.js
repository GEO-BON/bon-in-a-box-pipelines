import { useState, useEffect } from 'react';
import { Handle, Position } from 'react-flow-renderer/nocss';


const yaml = require('js-yaml');
const BonInABoxScriptService = require('bon_in_a_box_script_service');
const api = new BonInABoxScriptService.DefaultApi();

// props content, see https://reactflow.dev/docs/api/nodes/custom-nodes/#passed-prop-types
export default function IONode({ id, data }) {
  const [descriptionFileLocation] = useState(data.descriptionFile);
  const [metadata, setMetadata] = useState(null);

  useEffect(() => {
    if (descriptionFileLocation) {
      var callback = function (error, callbackData, response) {
        if (error) {
          console.error("Loading " + descriptionFileLocation + ": " + error.toString())
        } else {
          const newMetadata = yaml.load(callbackData)
          setMetadata(newMetadata)

          data.inputs = Object.entries(newMetadata.inputs).map(([inputName]) => {return inputName})
        }
      };

      api.getScriptInfo(descriptionFileLocation, callback);
    }
  }, [descriptionFileLocation])


  if (!metadata) return null
  return <table className='ioNode'><tbody>
    <tr>
      <td className='inputs'>
        {metadata.inputs && Object.entries(metadata.inputs).map(([inputName, desc]) => {
          return <ScriptIO key={inputName} desc={desc} setToolTip={data.setToolTip} onDoubleClick={(e)=>data.injectConstant(e, desc, id, inputName)}>
            <Handle id={inputName} type="target" position={Position.Left} />
            <span>{desc.label ? desc.label : inputName}</span>
          </ScriptIO>
        })}
      </td>
      <td className='name'>
        {metadata.script}
      </td>
      <td className='outputs'>
        {metadata.outputs && Object.entries(metadata.outputs).map(([outputName, desc]) => {
          return <ScriptIO key={outputName} desc={desc} setToolTip={data.setToolTip}>
            <span>{desc.label ? desc.label : outputName}</span>
            <Handle id={outputName} type="source" position={Position.Right} />
          </ScriptIO>
        })}
      </td>
    </tr>
  </tbody></table>
}

function ScriptIO({children, desc, setToolTip, onDoubleClick}) {
  function renderType(type) {
    if(type === 'options') {
      return "Options: " + desc.options.join(', ')
    } else {
      return type
    }
  }

  function onMouseEnter() {
    setToolTip(<>
      {desc.type && <>{renderType(desc.type)} <br /></>}
      {desc.description && <>{desc.description} <br /></>}
      {desc.example && <>Example: {desc.example.toString()}</>}
    </>)
  }

  function onMouseLeave() {
    setToolTip(null)
  }

  return <div onMouseEnter={onMouseEnter} onMouseLeave={onMouseLeave} onDoubleClick={onDoubleClick}>
    {children}
  </div>
}