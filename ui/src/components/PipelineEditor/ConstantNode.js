import { Handle, Position } from 'react-flow-renderer/nocss';

// props content, see https://reactflow.dev/docs/api/nodes/custom-nodes/#passed-prop-types
export default function TextUpdaterNode({ id, data }) {
  return (
    <div className='constant'>
      <div>
        <input id={id} placeholder='Constant' onChange={data.onChange} defaultValue={data.value} />
      </div>
      <Handle type="source" position={Position.Bottom} />
    </div>
  );
}