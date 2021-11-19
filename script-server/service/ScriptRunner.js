'use strict';


var scriptFolder = process.env.SCRIPT_LOCATION;

const Fs = require('fs')  
const Path = require('path')

/**
 * Run this script
 * Run the script specified in the URL. Must include the extension.
 *
 * scriptPath String Where to find the script in ./script folder
 * params String Additional parameters for the script (optional)
 * returns inline_response_200
 **/
exports.runScript = function (scriptPath, params) {
  console.log("Received " + scriptPath + " " + params)

  return new Promise(function (resolve, reject) {
    const script = Path.join(scriptFolder, scriptPath)

    if (Fs.existsSync(script)  ) {
      // This is a very basic way to run the script, we will probably change this.
      const exec = require('child_process').exec;
      const myShellScript = exec('Rscript ' + script, (error, stdout, stderr) => {
        // Send logs to browser after script ends
        if (error !== null) {
          resolve({
            "logs": "Error: " + stderr
          })
        } else {
          resolve({
            "files": ["presence.tiff", "uncertainty.tiff"],
            "logs": "Completed: " + stdout
          })
        }
      });

      // Realtime server logging
      myShellScript.stdout.on('data', (data) => { console.log(data); });
      myShellScript.stderr.on('data', (data) => { console.error(data); });

    } else {
      console.log('Script not found: ' + script)
      reject({
        "logs": "Script not found"
      });
    }
  });
}

