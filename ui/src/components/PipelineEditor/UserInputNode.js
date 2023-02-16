import { Handle, Position } from 'react-flow-renderer/nocss';

// props content, see https://reactflow.dev/docs/api/nodes/custom-nodes/#passed-prop-types
export default function UserInputNode({ id, data, type }) {

  return (
    <div className='userInput dragHandle'>
      <div style={{display: 'inline'}}>
        User Input ({data.type})
      </div>
      <button className='arrowDownButton' title='options' onClick={(e) => data.onPopupMenu(e, id, type)} />
      <Handle type="source" position={Position.Right} />
    </div>
  );
}