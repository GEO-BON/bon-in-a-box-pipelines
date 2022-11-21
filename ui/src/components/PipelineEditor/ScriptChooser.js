import './Editor.css'

import {React, useState, useEffect} from 'react';

const BonInABoxScriptService = require('bon_in_a_box_script_service');

const onDragStart = (event, nodeType, descriptionFile) => {
  event.dataTransfer.setData('application/reactflow', nodeType);
  event.dataTransfer.setData('descriptionFile', descriptionFile);
  event.dataTransfer.effectAllowed = 'move';
};

/**
 * 
 * @param {Array[String]} splitPathBefore Parent path, as a list of strings
 * @param {Array[Array[String]]} splitPathLeft List of remaining paths, each being split as a list of strings
 * @returns 
 */
function renderTree(splitPathBefore, splitPathLeft) {
  // Group them by folder
  let groupedFiles = new Map()
  splitPathLeft.forEach(path => {
    let first = path.shift() // first elem removed
    let key, value
    if (path.length > 0) {
      key = first
      value = path
    } else {
      key = ""
      value = first
    }

    if(!groupedFiles.get(key))
      groupedFiles.set(key, [])
      
    groupedFiles.get(key).push(value)
  })

  // Sort and output
  let sortedKeys = Array.from(groupedFiles.keys()).sort((a, b) => a.localeCompare(b, 'en', {sensitivity: 'base'}))
  return sortedKeys.map((key) => {
    if(key === "") { // leaf
      return groupedFiles.get(key).map(name => {
        let descriptionFile = [...splitPathBefore, name].join('>')
        return <div key={name} className="dndnode" onDragStart={(event) => onDragStart(event, 'io', descriptionFile)} draggable>
          <pre>{name}</pre>
        </div>
      })
    }
    
    // branch
    splitPathBefore.push(key)
    return <div key={key}>
      <p>{key}</p>
      <div className='inFolder'>{renderTree(splitPathBefore, groupedFiles.get(key))}</div>
    </div>
  })
}

export default function ScriptChooser() {
  const api = new BonInABoxScriptService.DefaultApi();
  const [scriptFiles, setScriptFiles] = useState([]);

  // Applied only once when first loaded  
  useEffect(() => {
    // Load list of scripts into scriptFileOptions
    api.scriptListGet((error, data, response) => {
      if (error) {
        // TODO: Client error
        console.error(error);
      } else {
        setScriptFiles(data);
      }
    });
    // Empty dependency array to get script list only once
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <aside className='scriptChooser'>
      <div className="dndnode output" onDragStart={(event) => onDragStart(event, 'output')} draggable>
        Pipeline output
      </div>
      <div className="description">Available scripts:</div>
      {scriptFiles && renderTree([], scriptFiles.map(file => file.split('>')))}
    </aside>
  );
};