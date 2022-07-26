import { getConnectedEdges } from 'react-flow-renderer/nocss';

/**
 * 
 * @param {Node[]} selectedNodes 
 * @param {Edge[]} allEdges 
 * @returns the edges, with added style for edges connected to the selected node.
 */
export const highlightConnectedEdges = (selectedNodes, allEdges) => {
  let connectedIds = []
  if (selectedNodes && selectedNodes.length === 1) {
    let connectedEdges = getConnectedEdges(selectedNodes, allEdges)
    connectedIds = connectedEdges.map((i) => i.id)
  }

  return allEdges.map((edge) => {
    edge.style = {
      ...edge.style,
      stroke: connectedIds.includes(edge.id) ? '#0000ff' : undefined
    }

    return edge
  })
}