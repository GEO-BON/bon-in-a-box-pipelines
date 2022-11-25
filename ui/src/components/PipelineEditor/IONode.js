import { useState, useEffect } from 'react';
import { Handle, Position } from 'react-flow-renderer/nocss';
import isObject from '../../utils/isObject'

import { fetchScriptDescription } from './ScriptDescriptionStore'

// props content, see https://reactflow.dev/docs/api/nodes/custom-nodes/#passed-prop-types
export default function IONode({ id, data }) {
  const [descriptionFileLocation] = useState(data.descriptionFile);
  const [metadata, setMetadata] = useState(null);

  useEffect(() => {
    if (descriptionFileLocation) {
      fetchScriptDescription(descriptionFileLocation, (newMetadata) => {
        setMetadata(newMetadata)
      })
    }
  }, [descriptionFileLocation])

  function showScriptTooltip() {
    data.setToolTip(metadata.description)
  }

  function hideTooltip() {
    data.setToolTip(null)
  }

  function checkForWarning(desc) {
    return !desc.label ? "Label missing in script's description file" :
      !desc.description ? "Description missing in script's description file" : null;
  }

  if (!metadata) return null
  return <table className='ioNode'><tbody>
    <tr>
      <td className='inputs'>
        {metadata.inputs && Object.entries(metadata.inputs).map(([inputName, desc]) => {
          let warning = checkForWarning(desc)

          return <ScriptIO key={inputName} desc={desc} setToolTip={data.setToolTip}
            onDoubleClick={(e) => data.injectConstant(e, desc, id, inputName)}
            warning={warning}>
            <Handle id={inputName} type="target" position={Position.Left} />
            <span className={warning && 'ioWarning'}>{desc.label ? desc.label : inputName}</span>
          </ScriptIO>
        })}
      </td>
      <td className='name' onMouseEnter={showScriptTooltip} onMouseLeave={hideTooltip}>
        {metadata.script}
      </td>
      <td className='outputs'>
        {metadata.outputs && Object.entries(metadata.outputs).map(([outputName, desc]) => {
          let warning = checkForWarning(desc)

          return <ScriptIO key={outputName} desc={desc} setToolTip={data.setToolTip} warning={warning}>
            <span className={warning && 'ioWarning'}>{desc.label ? desc.label : outputName}</span>
            <Handle id={outputName} type="source" position={Position.Right} />
          </ScriptIO>
        })}
      </td>
    </tr>
  </tbody></table>
}

function ScriptIO({children, desc, setToolTip, onDoubleClick, warning}) {
  function renderType(type) {
    if(type === 'options') {
      return "Options: " + (desc.options && desc.options.join(', '))
    } else {
      return type
    }
  }

  function onMouseEnter() {
    setToolTip(<>
      {warning && <><span className='warning'>{warning}</span><br/></>}
      {desc.type && <>{renderType(desc.type)} <br /></>}
      {desc.description && <>{desc.description} <br /></>}
      {desc.example && <>Example: {renderExample(desc.example)}</>}
    </>)
  }

  function renderExample(example){
    if(Array.isArray(example))
      return example.map((v, i) => renderExample(v) + (i === example.length - 1 ? "" : ", "))

    if(isObject(example))
      return JSON.stringify(example)

    if(example.includes("\n"))
      return <span style={{whiteSpace: "pre-wrap"}}>{"\n"+example.toString()}</span>

    return example.toString()
  }

  function onMouseLeave() {
    setToolTip(null)
  }

  return <div onMouseEnter={onMouseEnter} onMouseLeave={onMouseLeave} onDoubleClick={onDoubleClick}>
    {children}
  </div>
}