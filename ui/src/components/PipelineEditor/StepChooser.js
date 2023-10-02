import './StepChooser.css'

import {React, useState, useEffect, useCallback} from 'react';

import { fetchStepDescription } from './StepDescriptionStore';
import { StepDescription } from '../StepDescription';
import { Spinner } from '../Spinner';

const BonInABoxScriptService = require('bon_in_a_box_script_service');
const api = new BonInABoxScriptService.DefaultApi();

const onDragStart = (event, nodeType, descriptionFile) => {
  event.dataTransfer.setData('application/reactflow', nodeType);
  event.dataTransfer.setData('descriptionFile', descriptionFile);
  event.dataTransfer.effectAllowed = 'move';
};



export default function StepChooser({popupContent, setPopupContent}) {
  const [scriptFiles, setScriptFiles] = useState([]);
  const [pipelineFiles, setPipelineFiles] = useState([]);
  const [selectedStep, setSelectedStep] = useState([]);

  // Applied only once when first loaded  
  useEffect(() => {
    api.getListOf("pipeline", (error, pipelineList, response) => {
      if (error) {
        console.error(error);
      } else {
        setPipelineFiles(pipelineList)
      }
    });

    // Load list of scripts into scriptFileOptions
    api.getListOf("script", (error, scriptList, response) => {
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
      setPopupContent(<Spinner />)

      fetchStepDescription(descriptionFile, (metadata) => {
        if(!metadata) {
          setPopupContent(<p className='error'>Failed to fetch script description for {descriptionFile}</p>)
          return
        }

        setPopupContent(<StepDescription descriptionFile={descriptionFile} metadata={metadata} />)
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
    splitPathLeft.forEach(([path, stepName]) => {
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

      groupedFiles.get(key).push([value, stepName])
    })

    // Sort and output
    let sortedKeys = Array.from(groupedFiles.keys()).sort((a, b) => a.localeCompare(b, 'en', { sensitivity: 'base' }))
    return sortedKeys.map(key => {
      if (key === "") { // leaf
        return groupedFiles.get(key).map(([fileName, stepName]) => {

          let descriptionFile = [...splitPathBefore, fileName].join('>')
          return <div key={fileName} onDragStart={(event) => onDragStart(event, 'io', descriptionFile)} draggable
            title='Click for info, drag and drop to add to pipeline.'
            className={'dndnode' + (descriptionFile === selectedStep ? ' selected' : '')}
            onClick={() => onStepClick(descriptionFile)}>
            <pre>{stepName}</pre>
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
    <aside className='stepChooser'>
      <div className="dndnode output" onDragStart={(event) => onDragStart(event, 'output')} draggable>
        Pipeline output
      </div>
      {pipelineFiles &&
        <div key="Pipelines">
          <p>Pipelines</p>
          <div className='inFolder'>{renderTree([], Object.entries(pipelineFiles).map(entry => [entry[0].split('>'), entry[1]]))}</div>
        </div>
      }

      {scriptFiles && renderTree([], Object.entries(scriptFiles).map(entry => [entry[0].split('>'), entry[1]]))}
    </aside>
  );
};