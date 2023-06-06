import AutoResizeTextArea from './AutoResizeTextArea';

const yaml = require('js-yaml');

// https://stackoverflow.com/a/34491966/3519951
function isEmptyObject(obj) {
  for (var _ in obj) { return false; }
  return true;
}

export default function YAMLTextArea({ data, setData }) {

    if (isEmptyObject(data)) {
        return <textarea disabled={true} placeholder="No inputs" value="" />
    }

    return <AutoResizeTextArea className="inputFile"
        defaultValue={yaml.dump(data, { 'lineWidth': 124, 'sortKeys': true })}
        onBlur={(e) => setData(yaml.load(e.target.value))} />
}