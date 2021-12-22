'use strict';


/**
 * Get metadata about this script
 *
 * scriptPath String Where to find the script in ./script folder
 * returns String
 **/
exports.getScriptInfo = function(scriptPath) {
  return new Promise(function(resolve, reject) {
    var examples = {};
    examples['application/json'] = "http://server.com/scripts/somescript.md";
    if (Object.keys(examples).length > 0) {
      resolve(examples[Object.keys(examples)[0]]);
    } else {
      resolve();
    }
  });
}


/**
 * Run this script
 * Run the script specified in the URL. Must include the extension.
 *
 * scriptPath String Where to find the script in ./script folder
 * params List Additional parameters for the script (optional)
 * returns inline_response_200
 **/
exports.runScript = function(scriptPath,params) {
  return new Promise(function(resolve, reject) {
    var examples = {};
    examples['application/json'] = {
  "files" : {
    "presence" : "presence.tiff",
    "uncertainty" : "uncertainty.tiff"
  },
  "logs" : "Starting... Script completed!"
};
    if (Object.keys(examples).length > 0) {
      resolve(examples[Object.keys(examples)[0]]);
    } else {
      resolve();
    }
  });
}

