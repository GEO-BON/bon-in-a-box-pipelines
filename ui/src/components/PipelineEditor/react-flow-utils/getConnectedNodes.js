
import { getConnectedEdges } from 'react-flow-renderer/nocss';

/**
 * Given a list of nodes, get the list of upstream node directly connected to these nodes.
 * 
 * @param {import('react-flow-renderer/nocss').Node[]} nodes 
 * @param {import('react-flow-renderer/nocss').ReactFlowInstance} reactFlowInstance 
 */
export const getUpstreamNodes = (nodes, reactFlowInstance) => {
    const nodeIds = nodes.map(n => n.id)
    const connectedEdges = getConnectedEdges(nodes, reactFlowInstance.getEdges())
    const edgesUpstream = connectedEdges.filter(e => nodeIds.includes(e.target))
    return getUpstreamNodesFromEdges(edgesUpstream, reactFlowInstance.getNodes())
}

/**
 * Given a list of edges, find the list of nodes that are connected upstream.
 * 
 * @param {Edge[]} edges Edges that we look for.
 * @param {Node[]} allNodes All nodes of the graph
 */
export const getUpstreamNodesFromEdges = (edges, allNodes) => {
    const sourcesIds = edges.map(e => e.source)
    return allNodes.filter(node => sourcesIds.includes(node.id))
}

/**
 * Given a list of nodes, get the list of downstream node directly connected to these nodes.
 * 
 * @param {import('react-flow-renderer/nocss').Node[]} nodes 
 * @param {import('react-flow-renderer/nocss').ReactFlowInstance} reactFlowInstance 
 */
 export const getDownstreamNodes = (nodes, reactFlowInstance) => {
    const nodeIds = nodes.map(n => n.id)
    const connectedEdges = getConnectedEdges(nodes, reactFlowInstance.getEdges())
    const edgesDownstream = connectedEdges.filter(e => nodeIds.includes(e.source))
    return getDownstreamNodesFromEdges(edgesDownstream, reactFlowInstance.getNodes())
}

/**
 * Given a list of edges, find the list of nodes that are connected upstream.
 * 
 * @param {Edge[]} edges Edges that we look for.
 * @param {Node[]} allNodes All nodes of the graph
 */
export const getDownstreamNodesFromEdges = (edges, allNodes) => {
    const targetIds = edges.map(e => e.target)
    return allNodes.filter(node => targetIds.includes(node.id))
}