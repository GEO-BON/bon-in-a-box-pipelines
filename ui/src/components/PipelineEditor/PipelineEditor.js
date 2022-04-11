import 'react-flow-renderer/dist/style.css';
import 'react-flow-renderer/dist/theme-default.css';
import './Editor.css';

import React, { useState, useRef, useCallback } from 'react';
import ReactFlow, {
  ReactFlowProvider,
  addEdge,
  useNodesState,
  useEdgesState,
  Controls,
  MiniMap,
} from 'react-flow-renderer/nocss';

import IONode from './IONode'
import ConstantNode from './ConstantNode'

const initialNodes = [
  /*{
    id: '1',
    type: 'input',
    data: { label: 'input node' },
    position: { x: 250, y: 5 },
  },*/
];

const nodeTypes = {
  io: IONode,
  constant: ConstantNode
}

let id = 0;
const getId = () => `${id++}`;

export function PipelineEditor(props) {
  const reactFlowWrapper = useRef(null);
  const [nodes, setNodes, onNodesChange] = useNodesState(initialNodes);
  const [edges, setEdges, onEdgesChange] = useEdgesState([]);
  const [reactFlowInstance, setReactFlowInstance] = useState(null);

  const [toolTip, setToolTip] = useState(null);

  const inputFile = useRef(null) 

  const onConnect = useCallback((params) => setEdges((eds) => addEdge(params, eds)), []);

  const onDragOver = useCallback((event) => {
    event.preventDefault();
    event.dataTransfer.dropEffect = 'move';
  }, []);

  const onConstantValueChange = (event) => {
    setNodes((nds) =>
      nds.map((node) => {
        if(node.id !== event.target.id) {
          return node;
        }

        const value = event.target.value;
        return {
          ...node,
          data: {
            ...node.data,
            value,
          },
        };
      })
    );
  };

  const injectConstant = useCallback((event, dataType, target, targetHandle) => {
    event.preventDefault()
console.log(event)
    const reactFlowBounds = reactFlowWrapper.current.getBoundingClientRect()

    // Offset from pointer event to canvas
    const position = reactFlowInstance.project({
      x: event.clientX - reactFlowBounds.left,
      y: event.clientY - reactFlowBounds.top,
    })

    // Approx offset so the node appears near the input.
    position.x = position.x - 300
    position.y = position.y - 25

    const newNode = {
      id: getId(),
      type: 'constant',
      position,
      data: { 
        onChange: onConstantValueChange,
        type: dataType
       },
    }
    setNodes((nds) => nds.concat(newNode))

    const newEdge = {
      source: newNode.id,
      sourceHandle: null,
      target: target,
      targetHandle: targetHandle
    }
    setEdges((edgesList) => addEdge(newEdge, edgesList))
  }, [reactFlowInstance])

  const onDrop = useCallback(
    (event) => {
      event.preventDefault();

      const reactFlowBounds = reactFlowWrapper.current.getBoundingClientRect();
      const type = event.dataTransfer.getData('application/reactflow');
      const descriptionFile = event.dataTransfer.getData('descriptionFile');

      // check if the dropped element is valid
      if (typeof type === 'undefined' || !type) {
        return;
      }

      const position = reactFlowInstance.project({
        x: event.clientX - reactFlowBounds.left,
        y: event.clientY - reactFlowBounds.top,
      });

      let data;
      switch (type) {
        case 'io':
          data = { 
            descriptionFile: descriptionFile,
            setToolTip: setToolTip,
            injectConstant: injectConstant
           }
          break;
        case 'output':
          data = { label: 'Output' }
          break;
        default:
          throw Error("unknown node type")
      }

      const newNode = {
        id: getId(),
        type,
        position,
        data: data,
      };

      setNodes((nds) => nds.concat(newNode));
    },
    [reactFlowInstance]
  )

  const onSave = useCallback(() => {
    if (reactFlowInstance) {
      const flow = reactFlowInstance.toObject();
      navigator.clipboard.writeText(JSON.stringify(flow, null, 2))
      alert("Pipeline content copied to clipboard.\nUse git to add the code to BON in a Box's repository.")
    }
  }, [reactFlowInstance]);

  const loadFromFileBtnClick = () => {
    inputFile.current.click() // will call onLoad
  }

  const onLoad = (clickEvent) => {
    clickEvent.stopPropagation()
    clickEvent.preventDefault()

    var file = clickEvent.target.files[0]
    if (file) {
      var fr = new FileReader();
      fr.readAsText(file);
      fr.onload = loadEvent => {
        const flow = JSON.parse(loadEvent.target.result);
        if (flow) {
          id = 0
          flow.nodes.forEach(node => {
            // Make sure next id doesn't overlap
            id = Math.max(id, parseInt(node.id))

            switch (node.type) {
              case 'io':
                node.data.setToolTip = setToolTip
                node.data.injectConstant = injectConstant
                break;
              case 'constant':
                node.data.onChange = onConstantValueChange
                break;
            }
          })
          id++

          // Load the graph
          setNodes(flow.nodes || []);
          setEdges(flow.edges || []);
        } else {
          console.error("Error parsing flow")
        }
      }

      // Now that it's done, reset the value of the input.
      inputFile.current.value = ""
    }
  }



  return (
    <div className="dndflow">
      <ReactFlowProvider>
        <div className="reactflow-wrapper" ref={reactFlowWrapper}>
          <ReactFlow
            nodes={nodes}
            edges={edges}
            nodeTypes={nodeTypes}
            onNodesChange={onNodesChange}
            onEdgesChange={onEdgesChange}
            onConnect={onConnect}
            onInit={setReactFlowInstance}
            onDrop={onDrop}
            onDragOver={onDragOver}
            deleteKeyCode='Delete'
            fitView
          >
            {toolTip && <div className="tooltip">
              {toolTip}
            </div>}
            
            <div className="save__controls">
              <input type='file' id='file' ref={inputFile} accept="application/json"
                onChange={onLoad} style={{ display: 'none' }} />
              <button onClick={loadFromFileBtnClick}>Load from file</button>
              <button disabled={true}>Load from server</button>
              <button onClick={onSave}>Save</button>
            </div>

            <Controls />

            <MiniMap
              nodeStrokeColor={(n) => {
                if (n.type === 'constant') return '#0041d0';
                if (n.type === 'output') return '#ff0072';
                return 'black'
              }}
              nodeColor={(n) => {
                if (n.type === 'constant') return '#0041d0';
                if (n.type === 'output') return '#ff0072';
                return '#ffffff';
              }}
            />
          </ReactFlow>
        </div>
      </ReactFlowProvider>
    </div>
  );
};
