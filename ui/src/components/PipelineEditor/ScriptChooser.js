import './Editor.css'

import {React, useState, useEffect, useCallback} from 'react';

import spinnerImg from '../../img/spinner.svg';
import { fetchStepDescription } from './ScriptDescriptionStore';
import { GeneralDescription, InputsDescription, OutputsDescription } from '../ScriptDescription';

const BonInABoxScriptService = require('bon_in_a_box_script_service');
const api = new BonInABoxScriptService.DefaultApi();

const onDragStart = (event, nodeType, descriptionFile) => {
  event.dataTransfer.setData('application/reactflow', nodeType);
  event.dataTransfer.setData('descriptionFile', descriptionFile);
  event.dataTransfer.effectAllowed = 'move';
};



export default function ScriptChooser({popupContent, setPopupContent}) {
  const [scriptFiles, setScriptFiles] = useState([]);
  const [pipelineFiles, setPipelineFiles] = useState([]);
  const [selectedStep, setSelectedStep] = useState([]);

  // Applied only once when first loaded  
  useEffect(() => {
    api.pipelineListGet((error, pipelineList, response) => {
      if (error) {
        console.error(error);
      } else {
        setPipelineFiles(pipelineList)
      }
    });

    // Load list of scripts into scriptFileOptions
    api.scriptListGet((error, scriptList, response) => {
      if (error) {
        console.error(error);
      } else {
        setScriptFiles(scriptList);
      }
    });
  }, [setPipelineFiles, setScriptFiles]);

  const onStepClick = useCallback(descriptionFile => {
    if(selectedStep === descriptionFile) {
      setPopupContent(null) 
    } else {
      setSelectedStep(descriptionFile)
      setPopupContent(<img src={spinnerImg} className="spinner" alt="Spinner" />)

      fetchStepDescription(descriptionFile, (metadata) => {
        if(!metadata) {
          setPopupContent(<p className='error'>Failed to fetch script description for {descriptionFile}</p>)
          return
        }

        setPopupContent(<>
          <h2>{descriptionFile.replaceAll('>', ' > ')}</h2>
          <GeneralDescription ymlPath={descriptionFile} metadata={metadata} />
          <InputsDescription metadata={metadata} />
          <OutputsDescription metadata={metadata} />
        </>)
      })
    }
  }, [selectedStep, setSelectedStep, setPopupContent])

  // Removes the highlighting if popup closed with the X, or by re-clicking the step
  useEffect(() => {
    if(popupContent === null && selectedStep !== null) {
      setSelectedStep(null)
    }
  }, [popupContent, selectedStep, setSelectedStep])

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
      {pipelineFiles &&
        <div key="Pipelines">
          <p>Pipelines</p>
          <div className='inFolder'>{renderTree([], pipelineFiles.map(file => file.split('>')))}</div>
        </div>
      }

      {scriptFiles && renderTree([], scriptFiles.map(file => file.split('>')))}
    </aside>
  );
};