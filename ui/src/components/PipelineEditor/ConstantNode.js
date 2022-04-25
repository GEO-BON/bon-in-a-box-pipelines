import { Handle, Position } from 'react-flow-renderer/nocss';

export const ARRAY_PLACEHOLDER = 'Array';
export const CONSTANT_PLACEHOLDER = 'Constant';

// props content, see https://reactflow.dev/docs/api/nodes/custom-nodes/#passed-prop-types
export default function ConstantNode({ id, data }) {
  const placehodler = data.type.endsWith('[]') ? ARRAY_PLACEHOLDER : CONSTANT_PLACEHOLDER

  return (
    <div className='constant'>
      <label htmlFor={id}>{data.type} </label>
      <input id={id} placeholder={placehodler} onChange={data.onChange} defaultValue={data.value} />
      <Handle type="source" position={Position.Right} />
    </div>
  );
}