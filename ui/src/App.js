import logo from './logo.svg';
import './App.css';

function App() {
  return (
    <div className="App">
      <header className="App-header">
        <img src={logo} className="App-logo" alt="logo" />
        <p>
          Edit <code>src/App.js</code> and save to reload.
        </p>
        <a
          className="App-link"
          href="https://reactjs.org"
          target="_blank"
          rel="noopener noreferrer"
        >
          Learn React
        </a>
        <button onClick={query}>Test script server</button>
      </header>
    </div>
  );
}

function query() {
  var BonInABoxScriptService = require('bon_in_a_box_script_service');

  var api = new BonInABoxScriptService.DefaultApi()
  var scriptPath = "scriptPath_example"; // {String} Where to find the script in ./script folder
  var callback = function(error, data, response) {
    if (error) {
      alert(error)
      console.error(error);
    } else {
      alert('API called successfully. Returned data: ' + data)
      console.log('API called successfully. Returned data: ' + data);
    }
  };
  api.getScriptInfo(scriptPath, callback);
}

export default App;
