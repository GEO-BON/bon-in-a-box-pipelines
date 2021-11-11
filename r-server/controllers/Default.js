'use strict';

var utils = require('../utils/writer.js');
var Default = require('../service/DefaultService');

module.exports.runScript = function runScript (req, res, next, scriptPath) {
  Default.runScript(scriptPath)
    .then(function (response) {
      utils.writeJson(res, response);
    })
    .catch(function (response) {
      utils.writeJson(res, response);
    });
};
