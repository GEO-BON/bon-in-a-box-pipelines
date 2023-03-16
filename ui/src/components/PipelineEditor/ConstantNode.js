import { Handle, Position } from 'react-flow-renderer/nocss';

export const ARRAY_PLACEHOLDER = 'Array';
export const CONSTANT_PLACEHOLDER = 'Constant';

// props content, see https://reactflow.dev/docs/api/nodes/custom-nodes/#passed-prop-types
export default function ConstantNode({ id, data, type }) {

  function renderInput() {
    switch(data.type) {
      case 'options':
        if (data.options)
          return <select id={id} onChange={data.onChange} defaultValue={data.value}>
            {data.options.map(choice =>
              <option key={choice} value={choice}>{choice}</option>
            )}
          </select>

        else
          return <span className='ioWarning'>Options not defined</span>
      case 'boolean':
        return <input id={id} onChange={data.onChange} defaultValue={data.value} 
          type='checkbox' checked={data.value} />
      default: 
        return <input id={id} onChange={data.onChange} defaultValue={data.value}
          placeholder={data.type.endsWith('[]') ? ARRAY_PLACEHOLDER : CONSTANT_PLACEHOLDER}
          type='text' />
    }
  }

  return (
    <div className='constant'>
      <span className='dragHandle'>{data.type} </span>
      {renderInput()}
      <Handle type="source" position={Position.Right} />
      <button className='arrowDownButton' title='options' onClick={(e) => data.onPopupMenu(e, id, type)} />
    </div>
  );
}