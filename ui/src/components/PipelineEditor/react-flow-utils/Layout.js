import dagre from 'dagre';

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
  dagreGraph.setGraph({ rankdir: 'LR', nodesep: 10 });

  // Map to record the order of the inputs on the script card
  const inputOrderMap = new Map();

  nodes.forEach(node => {
    dagreGraph.setNode(node.id, { width: node.width, height: node.height });

    if (node.type === 'io') {
      inputOrderMap.set(node.id, node.data.inputs)
    }
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

  dagre.layout(dagreGraph);

  nodes.forEach((node) => {
    const nodeWithPosition = dagreGraph.node(node.id);
    node.targetPosition = 'left';
    node.sourcePosition = 'right';

    node.position = {
      x: nodeWithPosition.x - node.width,
      y: nodeWithPosition.y - node.height / 2
    };

    return node;
  });

  return { nodes, edges };
};