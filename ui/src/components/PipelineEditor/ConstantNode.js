import { Handle, Position } from 'react-flow-renderer/nocss';

// props content, see https://reactflow.dev/docs/api/nodes/custom-nodes/#passed-prop-types
export default function TextUpdaterNode({ id, data }) {
  return (
    <div className='constant'>
      <label htmlFor={id}>{data.type} </label>
      <input id={id} placeholder='Constant' onChange={data.onChange} defaultValue={data.value} />
      <Handle type="source" position={Position.Right} />
    </div>
  );
}