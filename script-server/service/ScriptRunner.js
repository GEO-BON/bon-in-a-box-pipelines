'use strict';

var scriptFolder = process.env.SCRIPT_LOCATION;

const utils = require('../utils/responseWriters.js');
const Fs = require('fs')  
const Path = require('path')
const MD5 = require('crypto-js/md5')

/**
 * Run this script
 * Run the script specified in the URL. Must include the extension.
 *
 * scriptPath String Where to find the script in ./script folder
 * params List Additional parameters for the script (optional)
 * returns a responseWriter object
 **/
exports.runScript = function (scriptFile, params) {
  console.log("Received " + scriptFile + " " + params)

  return new Promise(function (resolve, reject) {
    // Make sure the script exists
    const scriptPath = Path.join(scriptFolder, scriptFile)
    if (!Fs.existsSync(scriptPath)) {
      console.log('Script not found: ' + scriptPath)
      reject(utils.JsonResponse({
        "logs": "Script not found"
      }, 404))
      return
    }

    // Create the ouput folder based for this invocation
    const outputFolder = getOutputFolder(scriptFile, params);
    if (!Fs.existsSync(outputFolder)) {
      Fs.mkdirSync(outputFolder, { recursive: true });
    }

    // TODO#20: getCommand(script)

    // Run the script
    const exec = require('child_process').exec;
    const shellScript = exec(
      `Rscript ${scriptPath} ${outputFolder} `
      + (params == undefined ? '' : params.join(' ')),
      (error, stdout, stderr) => {

        if (error === null) {
          const outputFile = Path.join(outputFolder, 'output.json')
          if (!Fs.existsSync(outputFile)) {
            console.error(stderr = "output.json file not found")

          } else {
            // Read output.json
            try {
              var outputs = JSON.parse(Fs.readFileSync(outputFile, { encoding: 'utf8', flag: 'r' }))
              resolve(utils.JsonResponse({
                "files": outputs,
                "logs": "Completed: " + stdout
              }))
              return

            } catch (ex) {
              console.error(ex);
              stderr = ex
            }
          }
        }

        // Send error logs as response
        reject(utils.JsonResponse({
          "logs": "Error: " + stderr + "\n\nFull logs: " + stdout
        }, 500))
      });

    // Realtime server logging
    shellScript.stdout.on('data', (data) => { console.log(data); });
    shellScript.stderr.on('data', (data) => { console.error(data); });
  });
}

/**
 * Get metadata about this script
 *
 * scriptPath String Where to find the script in ./script folder
 * returns String
 **/
 exports.getScriptInfo = function(scriptFile) {
  return new Promise(function(resolve, reject) {
    try {
      console.log("scriptPath=" + scriptFile)
      const scriptPath = Path.join(scriptFolder, scriptFile)

      // Replace extension by .md
      let mdPath = scriptPath.replace(/\.\w+$/, '.md')
      console.log("mdPath=" + mdPath)

      let content = Fs.readFileSync(mdPath, { encoding: 'utf8', flag: 'r' })
      console.log("lenght=" + content.length)

      resolve(utils.TextResponse(content));
    }
    catch (ex) {
      reject(utils.TextResponse(ex.message, 404))
    }
  });
 }

/**
 * 
 * @param {String} scriptFile 
 * @param {List} params 
 * @returns a folder for this invocation. Invoking with the same params will always give the same output folder.
 */
function getOutputFolder(scriptFile, params) {
  return Path.join(
    process.env.OUTPUT_LOCATION,
    scriptFile.replace('.', '_'),
    params == undefined ? 'no_params' : MD5(params).toString())
}
