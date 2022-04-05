import { Handle, Position } from 'react-flow-renderer/nocss';

// props content, see https://reactflow.dev/docs/api/nodes/custom-nodes/#passed-prop-types
export default function TextUpdaterNode({ id, data }) {
  return (
    <>
      <div>
        <label htmlFor="text">Constant:</label>
        <input id={id} name="text" onChange={data.onChange} defaultValue={data.value} />
      </div>
      <Handle type="source" position={Position.Bottom} />
    </>
  );
}