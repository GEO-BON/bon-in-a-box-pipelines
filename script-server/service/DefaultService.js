'use strict';


/**
 * Run this script
 * Run this script ... decription ...
 *
 * scriptPath String Where to find the script in ./script folder
 * returns inline_response_200
 **/
exports.runScript = function(scriptPath) {
  return new Promise(function(resolve, reject) {
    var examples = {};
    examples['application/json'] = {
  "file" : "map.tiff",
  "message" : "Script completed!"
};
    if (Object.keys(examples).length > 0) {
      resolve(examples[Object.keys(examples)[0]]);
    } else {
      resolve();
    }
  });
}

