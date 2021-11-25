'use strict';

var utils = require('../utils/writer.js');
var Default = require('../service/DefaultService');
var runner = require('../service/ScriptRunner');

module.exports.getScriptInfo = function getScriptInfo (req, res, next, scriptPath) {
  Default.getScriptInfo(scriptPath)
    .then(function (response) {
      utils.writeJson(res, response);
    })
    .catch(function (response) {
      utils.writeJson(res, response);
    });
};

module.exports.runScript = function runScript (req, res, next, params, scriptPath) {
  // For some reason, received as (params, scriptPath) instead of (scriptPath, params), so we flip it here.
  runner.runScript(scriptPath, params)
    .then(function (response) {
      utils.writeJson(res, response);
    })
    .catch(function (response) {
      utils.writeJson(res, response);
    });
};
