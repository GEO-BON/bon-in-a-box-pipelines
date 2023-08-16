import AutoResizeTextArea from './AutoResizeTextArea';
import { isEmptyObject } from '../../utils/isEmptyObject';

const yaml = require('js-yaml');

export default function YAMLTextArea({ data, setData }) {

    if (isEmptyObject(data)) {
        return <textarea disabled={true} placeholder="No inputs" value="" />
    }

    return <AutoResizeTextArea className="inputFile"
        defaultValue={yaml.dump(data, { 'lineWidth': 124, 'sortKeys': true })}
        onBlur={(e) => setData(yaml.load(e.target.value))} />
}