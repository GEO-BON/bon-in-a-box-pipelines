import dagre from 'dagre';
import { getScriptDescription } from '../ScriptDescriptionStore'

const ELK = require('elkjs')
const elk = new ELK()

/**
 * 
 * @param Nodes nodes 
 * @param Edges edges 
 * @param Function callback receiving the modified nodes object with the new positions
 */
export const layoutElements = (nodes, edges, callback) => {
  let graph = {
    id: 'root',
    layoutOptions: {
      algorithm: 'layered',
      'layered.spacing.edgeNodeBetweenLayers': 50,
      'spacing.nodeNode': 10
    },
  }

  graph.children = nodes.map(node => {
    let elkjsNode = {
      id: node.id,
      width: node.width,
      height: node.height,
    }

    if (node.type === 'io') {
      const desc = getScriptDescription(node.data.descriptionFile)
      if(desc){
        elkjsNode.ports = Object.keys(desc.outputs).map((output, ix) => {
          return {
            id: node.id + '.out.' + output,
            side: 'EAST',
            index: ix,
            y: ix, // specifying y gives the top-down order of the ports
          }
        })
  
        if (desc.inputs) { // There might not always be inputs
          Object.keys(desc.inputs).forEach((input, ix) => {
            elkjsNode.ports.push({
              id: node.id + '.in.' + input,
              side: 'WEST',
              index: ix,
              y: ix, // specifying y gives the top-down order of the ports
            })
          })
        }
  
        elkjsNode.properties = {
          portConstraints: 'FIXED_ORDER',
          'portAlignment.default': 'BEGIN'
        }
      } else {
        console.error('Failed ot get description for ' + node.data.descriptionFile)
      }
    }

    return elkjsNode
  });

  graph.edges = edges.map(edge => {
    return {
      id: edge.id,
      sources: [edge.sourceHandle ? edge.source + '.out.' + edge.sourceHandle : edge.source],
      targets: [edge.targetHandle ? edge.target + '.in.' + edge.targetHandle : edge.target]
    }
  });

  elk.layout(graph)
   .then(result => {
    console.log(result)
      // Transfer result to react-flow graph
      nodes.forEach((reactFlowNode) => {
        const elkjsNode = result.children.find(n => n.id === reactFlowNode.id)
        reactFlowNode.position = {
          x: elkjsNode.x,
          y: elkjsNode.y
        };
      });

      callback(nodes)
   })
   .catch(console.error)
}


/**
 * Reposition nodes using dagree graph. 
 * 
 * @param {Node[]} nodes 
 * @param {Edge[]} edges 
 * @returns (Node[], Edge[]) the provided lists modified to layout the elements
 * @deprecated
 */
export const layoutElementsDagre = (nodes, edges) => {
  const dagreGraph = new dagre.graphlib.Graph();
  dagreGraph.setDefaultEdgeLabel(() => ({}));
  dagreGraph.setGraph({ rankdir: 'LR', nodesep: 10, align: undefined, ranksep: 150 });

  // Map to record the order of the inputs on the script card
  const inputOrderMap = new Map();
  nodes.forEach(node => {
    if (node.type === 'io') {
      let inputList = []
      Object.keys(getScriptDescription(node.data.descriptionFile).inputs).forEach(inputKey => inputList.push(inputKey))
      inputOrderMap.set(node.id, inputList)
    }

    dagreGraph.setNode(node.id, { width: node.width, height: node.height });
  });

  // Sort the edges in the order that they appear on the card
  edges.sort((edge1, edge2) => {
    let edge1Value = 0
    let nodeInputs = inputOrderMap.get(edge1.target)
    if (nodeInputs) edge1Value += nodeInputs.indexOf(edge1.targetHandle)


    let edge2Value = 0
    nodeInputs = inputOrderMap.get(edge2.target)
    if (nodeInputs) edge2Value += nodeInputs.indexOf(edge2.targetHandle)

    return edge1Value - edge2Value
  });

  edges.forEach((edge) => {
    dagreGraph.setEdge(edge.source, edge.target);
  });

  // Layout
  dagre.layout(dagreGraph);

  // In order to align right, we keep the width of the largest node in the rank. 
  // Rank is not in the outputs, but all nodes from the same rank share the same x.
  let centerToWidth = {}
  nodes.forEach((renderNode) => {
    const dagreNode = dagreGraph.node(renderNode.id);
    if(!centerToWidth[dagreNode.x] || centerToWidth[dagreNode.x] < dagreNode.width) {
      centerToWidth[dagreNode.x] = dagreNode.width
    }
  })

  // Transfer result to react-flow graph
  nodes.forEach((renderNode) => {
    const dagreNode = dagreGraph.node(renderNode.id);
    renderNode.targetPosition = 'left';
    renderNode.sourcePosition = 'right';

    const rankOffset = centerToWidth[dagreNode.x] / 2
    renderNode.position = {
      x: dagreNode.x + rankOffset - renderNode.width,
      y: dagreNode.y - renderNode.height / 2
    };

    return renderNode;
  });

  return { nodes, edges };
};