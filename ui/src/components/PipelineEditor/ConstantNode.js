import { Handle, Position } from 'react-flow-renderer/nocss';

export const ARRAY_PLACEHOLDER = 'Array';
export const CONSTANT_PLACEHOLDER = 'Constant';

// props content, see https://reactflow.dev/docs/api/nodes/custom-nodes/#passed-prop-types
export default function ConstantNode({ id, data }) {

  return (
    <div className='constant'>
      <label className='dragHandle' htmlFor={id}>{data.type} </label>
      <input id={id} onChange={data.onChange} defaultValue={data.value}
        placeholder={data.type.endsWith('[]') ? ARRAY_PLACEHOLDER : CONSTANT_PLACEHOLDER}
        type={data.type === 'boolean' ? 'checkbox' : 'text'}
        checked={data.value} />

      <Handle type="source" position={Position.Right} />
    </div>
  );
}