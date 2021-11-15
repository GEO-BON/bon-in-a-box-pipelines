'use strict';

var utils = require('../utils/writer.js');
var runner = require('../service/ScriptRunner');

module.exports.runScript = function runScript (req, res, next, scriptPath) {
  runner.runScript(scriptPath)
    .then(function (response) {
      utils.writeJson(res, response);
    })
    .catch(function (response) {
      utils.writeJson(res, response);
    });
};
