import dagre from 'dagre';
import { getScriptDescription } from '../ScriptDescriptionStore'

/**
 * Reposition nodes using dagree graph. 
 * 
 * @param {Node[]} nodes 
 * @param {Edge[]} edges 
 * @returns (Node[], Edge[]) the provided lists modified to layout the elements
 */
export const getLayoutedElements = (nodes, edges) => {
  const dagreGraph = new dagre.graphlib.Graph();
  dagreGraph.setDefaultEdgeLabel(() => ({}));
  dagreGraph.setGraph({ rankdir: 'LR', nodesep: 10, align: undefined });

  // To be able to align right, we need to know the with of the longest constant value attached to a node.
  let longestConstantMap = {}

  // Map to record the order of the inputs on the script card
  const inputOrderMap = new Map();
  nodes.forEach(node => {
    let nodeProperties = { width: node.width, height: node.height }

    if (node.type === 'io') {
      let inputList = []
      Object.keys(getScriptDescription(node.data.descriptionFile).inputs).forEach(inputKey => inputList.push(inputKey))
      inputOrderMap.set(node.id, inputList)

    } else if (node.type === 'constant') {
      edges.forEach((edge) => {
        // record width if this is the longest constant
        if (edge.source === node.id) {
          if (!longestConstantMap[edge.target] || longestConstantMap[edge.target] < node.width) {
            longestConstantMap[edge.target] = node.width
          }

          // record connected ids to be able to find the above
          nodeProperties.connectedTo ? nodeProperties.connectedTo.push(edge.target) : nodeProperties.connectedTo = [edge.target]
        }
      })
    }

    dagreGraph.setNode(node.id, nodeProperties);
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

  // Transfer result to react-flow graph
  nodes.forEach((renderNode) => {
    const dagreNode = dagreGraph.node(renderNode.id);
    renderNode.targetPosition = 'left';
    renderNode.sourcePosition = 'right';

    if (renderNode.type === 'constant' && dagreNode.connectedTo && dagreNode.connectedTo.length === 1) {
      let maxWidth = longestConstantMap[dagreNode.connectedTo[0]]
      renderNode.position = {
        x: dagreNode.x + maxWidth / 2 - renderNode.width, // right align
        y: dagreNode.y - renderNode.height / 2
      };
    } else {
      renderNode.position = {
        x: dagreNode.x - renderNode.width / 2,
        y: dagreNode.y - renderNode.height / 2
      };
    }

    return renderNode;
  });

  return { nodes, edges };
};