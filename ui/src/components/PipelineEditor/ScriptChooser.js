import './Editor.css'

import {React, useState, useEffect, useCallback} from 'react';

const BonInABoxScriptService = require('bon_in_a_box_script_service');

const onDragStart = (event, nodeType, descriptionFile) => {
  event.dataTransfer.setData('application/reactflow', nodeType);
  event.dataTransfer.setData('descriptionFile', descriptionFile);
  event.dataTransfer.effectAllowed = 'move';
};



export default function ScriptChooser({popupContent, setPopupContent}) {
  const api = new BonInABoxScriptService.DefaultApi();
  const [scriptFiles, setScriptFiles] = useState([]);
  const [selectedStep, setSelectedStep] = useState([]);

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

  const onStepClick = useCallback(descriptionFile => {
    if(selectedStep === descriptionFile) {
      setPopupContent(null) 
    } else {
      setSelectedStep(descriptionFile)
      setPopupContent(descriptionFile) // TODO: TEMP
    }
  })

  // Removes the highlighting if popup closed with the X, or by re-clicking the step
  useEffect(() => {
    if(popupContent === null && selectedStep !== null) {
      setSelectedStep(null)
    }
  }, [popupContent])

  /**
   *
   * @param {Array[String]} splitPathBefore Parent path, as a list of strings
   * @param {Array[Array[String]]} splitPathLeft List of remaining paths, each being split as a list of strings
   * @returns
   */
  const renderTree = useCallback((splitPathBefore, splitPathLeft) => {
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

      if (!groupedFiles.get(key))
        groupedFiles.set(key, [])

      groupedFiles.get(key).push(value)
    })

    // Sort and output
    let sortedKeys = Array.from(groupedFiles.keys()).sort((a, b) => a.localeCompare(b, 'en', { sensitivity: 'base' }))
    return sortedKeys.map((key) => {
      if (key === "") { // leaf
        return groupedFiles.get(key).map(name => {
          let descriptionFile = [...splitPathBefore, name].join('>')

          return <div key={name} onDragStart={(event) => onDragStart(event, 'io', descriptionFile)} draggable
            title='Click for info, drag and drop to add to pipeline.'
            className={'dndnode' + (descriptionFile === selectedStep ? ' selected' : '')}
            onClick={() => onStepClick(descriptionFile)}>
            <pre>{name}</pre>
          </div>
        })
      }

      // branch
      return <div key={key}>
        <p>{key}</p>
        <div className='inFolder'>{renderTree([...splitPathBefore, key], groupedFiles.get(key))}</div>
      </div>
    })
  }, [onStepClick, selectedStep])

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