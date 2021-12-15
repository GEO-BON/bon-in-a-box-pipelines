'use strict';

var Default = require('../service/DefaultService');
var runner = require('../service/ScriptRunner');

module.exports.getScriptInfo = function getScriptInfo (req, res, next, scriptPath) {
  runner.getScriptInfo(scriptPath)
    .then(function (result) {
      result.write(res)
    })
    .catch(function (result) {
      result.write(res)
    });
};

module.exports.runScript = function runScript (req, res, next, params, scriptPath) {
  // For some reason, received as (params, scriptPath) instead of (scriptPath, params), so we flip it here.
  runner.runScript(scriptPath, params)
    .then(function (result) {
      result.write(res)
    })
    .catch(function (result) {
      result.write(res)
    });
};
