import { Handle, Position } from 'react-flow-renderer/nocss';
import ScriptInput from '../form/ScriptInput';

// props content, see https://reactflow.dev/docs/api/nodes/custom-nodes/#passed-prop-types
export default function ConstantNode({ id, data, type }) {

  return (
    <div className='constant'>
      <p className='dragHandle'>{data.type} </p>
      <ScriptInput id={id} type={data.type} value={data.value} options={data.options}
        onValueUpdated={v => data.onConstantValueChange(id, v)} />
      <Handle type="source" position={Position.Right} />
      <button className='arrowDownButton' title='options' onClick={(e) => data.onPopupMenu(e, id, type)} />
    </div>
  );
}