'use strict';


var scriptFolder = process.env.SCRIPT_LOCATION;

const utils = require('../utils/writer.js');
const Fs = require('fs')  
const Path = require('path')

/**
 * Run this script
 * Run the script specified in the URL. Must include the extension.
 *
 * scriptPath String Where to find the script in ./script folder
 * params List Additional parameters for the script (optional)
 * returns inline_response_200
 **/
exports.runScript = function (scriptPath, params) {
  console.log("Received " + scriptPath + " " + params)

  return new Promise(function (resolve, reject) {
    const script = Path.join(scriptFolder, scriptPath)

    if (Fs.existsSync(script)  ) {
      const exec = require('child_process').exec;

// TODO#20: getCommand(script)

      const shellScript = exec(`Rscript ${script} ${params.join(' ')}`, (error, stdout, stderr) => {

        if (error === null) {
          // End of stdout should be the JSON array of outputs
          var outputs = JSON.parse('{}')
          const jsonstart = stdout.lastIndexOf('{')
          if (jsonstart == -1) {
            console.error(stderr = "no JSON map found for outputs")

          } else {
            var jsonstr = stdout.substr(jsonstart)
            console.log("jsonstr: " + jsonstr)
            try {
              outputs = JSON.parse(jsonstr);
              resolve({
                "files": outputs,
                "logs": "Completed: " + stdout
              })
              return

            } catch (ex) {
              console.error(ex);
              stderr = ex
            }
          }
        }

        // Send error logs as response
        reject(utils.respondWithCode(500, {
          "logs": "Error: " + stderr + "\n\nFull logs: " + stdout
        }))
      });

      // Realtime server logging
      shellScript.stdout.on('data', (data) => { console.log(data); });
      shellScript.stderr.on('data', (data) => { console.error(data); });

    } else {
      console.log('Script not found: ' + script)
      reject(utils.respondWithCode(404, {
        "logs": "Script not found"
      }))
    }
  });
}

