import { Handle, Position } from 'react-flow-renderer/nocss';

export default function TextUpdaterNode({ data }) {
  return (
    <>
      <div>
        <label htmlFor="text">Constant:</label>
        <input id={data.id} name="text" onChange={data.onChange} defaultValue={data.value} />
      </div>
      <Handle type="source" position={Position.Bottom} />
    </>
  );
}