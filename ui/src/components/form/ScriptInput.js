import AutoResizeTextArea from './AutoResizeTextArea'

export const ARRAY_PLACEHOLDER = 'Array (comma-separated)';
export const CONSTANT_PLACEHOLDER = 'Constant';

export default function ScriptInput({ type, value, options, onValueUpdated, ...passedProps }) {

  if(type.endsWith('[]')) {
    return <AutoResizeTextArea {...passedProps}
        defaultValue={value && typeof value.join === 'function' ? value.join(', ') : value}
        placeholder={ARRAY_PLACEHOLDER}
        onBlur={e => {
          const value = e.target.value
          if(!value || value === "") {
            onValueUpdated([])
          } else {
            onValueUpdated(e.target.value.split(',').map(v=>v.trim()))}
          }
        } />
  }

  switch (type) {
    case 'options':
      if (options) {
        return <select {...passedProps}
          value={value}
          onChange={e => onValueUpdated(e.target.value)}>
          <option hidden></option> {/* Allows the box to be empty when value not set */}
          {options.map(choice =>
            <option key={choice} value={choice}>{choice}</option>
          )}
        </select>

      } else {
        return <span className='ioWarning'>Options not defined</span>
      }

    case 'boolean':
      return <input type='checkbox' {...passedProps}
        defaultChecked={value}
        onChange={e => onValueUpdated(e.target.checked)}  />

    case 'int':
      return <input type='text' {...passedProps} defaultValue={value}
        placeholder={CONSTANT_PLACEHOLDER}
        onBlur={e => onValueUpdated(parseInt(e.target.value))} />

    case 'float':
      return <input type='text' {...passedProps} defaultValue={value}
        placeholder={CONSTANT_PLACEHOLDER}
        onBlur={e => onValueUpdated(parseFloat(e.target.value))} />

    default:
      return <input type='text' {...passedProps} defaultValue={value}
        placeholder={CONSTANT_PLACEHOLDER}
        onBlur={e => onValueUpdated(e.target.value)} />
  }
}
