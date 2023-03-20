import dagre from 'dagre';
import { getStepDescription } from '../ScriptDescriptionStore'

/**
 * Reposition nodes using dagree graph. 
 * 
 * @param {Node[]} nodes 
 * @param {Edge[]} edges 
 * @returns (Node[], Edge[]) the provided lists modified to layout the elements
 */
export const layoutElements = (nodes, edges) => {
  const dagreGraph = new dagre.graphlib.Graph();
  dagreGraph.setDefaultEdgeLabel(() => ({}));
  dagreGraph.setGraph({ rankdir: 'LR', nodesep: 10, align: undefined, ranksep: 150 });

  // Map to record the order of the inputs on the script card
  const inputOrderMap = new Map();
  nodes.forEach(node => {
    if (node.type === 'io') {
      let inputList = []
      Object.keys(getStepDescription(node.data.descriptionFile).inputs).forEach(inputKey => inputList.push(inputKey))
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