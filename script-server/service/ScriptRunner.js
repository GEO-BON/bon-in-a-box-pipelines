'use strict';


var scriptFolder = process.env.SCRIPT_LOCATION;

const Fs = require('fs')  
const Path = require('path')

/**
 * Run this script
 * Run this script ... decription ...
 *
 * scriptPath String Where to find the script in ./script folder
 * returns inline_response_200
 **/
exports.runScript = function (scriptPath) {
  return new Promise(function (resolve, reject) {
    const script = Path.join(scriptFolder, scriptPath)
    
    if (Fs.existsSync(script)  ) {
      // This is a very basic way to run the script, we will probably change this.
      const exec = require('child_process').exec;
      const myShellScript = exec('Rscript ' + script, (error, stdout, stderr) => {
        // Send logs to browser after script ends
        if (error !== null) {
          resolve({
            "message": "Error: " + stderr
          })
        } else {
          resolve({
            "file": "map.tiff",
            "message": "Completed: " + stdout
          })
        }
      });

      // Realtime server logging
      myShellScript.stdout.on('data', (data) => { console.log(data); });
      myShellScript.stderr.on('data', (data) => { console.error(data); });

    } else {
      console.log('Script not found: ' + script)
      reject({
        "message": "Script not found"
      });
    }
  });
}

