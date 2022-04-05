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
  {
    id: '1',
    type: 'input',
    data: { label: 'input node' },
    position: { x: 250, y: 5 },
  },
];

const nodeTypes = {
  io: IONode,
  constant: ConstantNode
}

let id = 0;
const getId = () => `node_${id++}`;

export function PipelineEditor(props) {
  const reactFlowWrapper = useRef(null);
  const [nodes, setNodes, onNodesChange] = useNodesState(initialNodes);
  const [edges, setEdges, onEdgesChange] = useEdgesState([]);
  const [reactFlowInstance, setReactFlowInstance] = useState(null);

  const onConnect = useCallback((params) => setEdges((eds) => addEdge(params, eds)), []);

  const onDragOver = useCallback((event) => {
    event.preventDefault();
    event.dataTransfer.dropEffect = 'move';
  }, []);

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

      let id = getId();
      let data;
      switch (type) {
        case 'io':
          data = { descriptionFile: descriptionFile }
          break;
        case 'constant':
          data = {
            id: id,
            onChange: onConstantValueChange
          }
          break;
        default:
          data = { label: `${type} node` }
      }

      const newNode = {
        id: id,
        type,
        position,
        data: data,
        descriptionFile: descriptionFile
      };

      setNodes((nds) => nds.concat(newNode));
    },
    [reactFlowInstance]
  );

  const onConstantValueChange = (event) => {
    setNodes((nds) =>
      nds.map((node) => {
        if(node.id != event.target.id) {
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
            <Controls />
            <MiniMap />
          </ReactFlow>
        </div>
      </ReactFlowProvider>
    </div>
  );
};
