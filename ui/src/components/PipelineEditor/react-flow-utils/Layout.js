import { getStepDescription } from '../StepDescriptionStore'

// For ELK options, refer to https://www.eclipse.org/elk/reference/options.html
// Some examples: http://rtsys.informatik.uni-kiel.de/elklive/examples.html?e=user-hints%2Flayered%2FverticalOrder
// However, they are not in elk-js, and it is tricky to convert!
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
      const desc = getStepDescription(node.data.descriptionFile)
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
          alignment: 'RIGHT',
          portConstraints: 'FIXED_ORDER',
          'portAlignment.default': 'BEGIN'
        }
      } else {
        console.error('Failed to get description for ' + node.data.descriptionFile)
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
