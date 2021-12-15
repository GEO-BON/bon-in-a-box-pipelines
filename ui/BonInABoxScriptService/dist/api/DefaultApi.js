"use strict";

Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.default = void 0;

var _ApiClient = _interopRequireDefault(require("../ApiClient"));

var _InlineResponse = _interopRequireDefault(require("../model/InlineResponse200"));

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { default: obj }; }

function _classCallCheck(instance, Constructor) { if (!(instance instanceof Constructor)) { throw new TypeError("Cannot call a class as a function"); } }

function _defineProperties(target, props) { for (var i = 0; i < props.length; i++) { var descriptor = props[i]; descriptor.enumerable = descriptor.enumerable || false; descriptor.configurable = true; if ("value" in descriptor) descriptor.writable = true; Object.defineProperty(target, descriptor.key, descriptor); } }

function _createClass(Constructor, protoProps, staticProps) { if (protoProps) _defineProperties(Constructor.prototype, protoProps); if (staticProps) _defineProperties(Constructor, staticProps); return Constructor; }

/**
* Default service.
* @module api/DefaultApi
* @version 1.0.0
*/
var DefaultApi = /*#__PURE__*/function () {
  /**
  * Constructs a new DefaultApi. 
  * @alias module:api/DefaultApi
  * @class
  * @param {module:ApiClient} [apiClient] Optional API client implementation to use,
  * default to {@link module:ApiClient#instance} if unspecified.
  */
  function DefaultApi(apiClient) {
    _classCallCheck(this, DefaultApi);

    this.apiClient = apiClient || _ApiClient.default.instance;
  }
  /**
   * Callback function to receive the result of the getScriptInfo operation.
   * @callback module:api/DefaultApi~getScriptInfoCallback
   * @param {String} error Error message, if any.
   * @param {String} data The data returned by the service call.
   * @param {String} response The complete HTTP response.
   */

  /**
   * Get metadata about this script
   * @param {String} scriptPath Where to find the script in ./script folder
   * @param {module:api/DefaultApi~getScriptInfoCallback} callback The callback function, accepting three arguments: error, data, response
   * data is of type: {@link String}
   */


  _createClass(DefaultApi, [{
    key: "getScriptInfo",
    value: function getScriptInfo(scriptPath, callback) {
      var postBody = null; // verify the required parameter 'scriptPath' is set

      if (scriptPath === undefined || scriptPath === null) {
        throw new Error("Missing the required parameter 'scriptPath' when calling getScriptInfo");
      }

      var pathParams = {
        'scriptPath': scriptPath
      };
      var queryParams = {};
      var headerParams = {};
      var formParams = {};
      var authNames = [];
      var contentTypes = [];
      var accepts = ['application/json'];
      var returnType = 'String';
      return this.apiClient.callApi('/info/{scriptPath}', 'GET', pathParams, queryParams, headerParams, formParams, postBody, authNames, contentTypes, accepts, returnType, null, callback);
    }
    /**
     * Callback function to receive the result of the runScript operation.
     * @callback module:api/DefaultApi~runScriptCallback
     * @param {String} error Error message, if any.
     * @param {module:model/InlineResponse200} data The data returned by the service call.
     * @param {String} response The complete HTTP response.
     */

    /**
     * Run this script
     * Run the script specified in the URL. Must include the extension.
     * @param {String} scriptPath Where to find the script in ./script folder
     * @param {Object} opts Optional parameters
     * @param {Array.<String>} opts.params Additional parameters for the script
     * @param {module:api/DefaultApi~runScriptCallback} callback The callback function, accepting three arguments: error, data, response
     * data is of type: {@link module:model/InlineResponse200}
     */

  }, {
    key: "runScript",
    value: function runScript(scriptPath, opts, callback) {
      opts = opts || {};
      var postBody = null; // verify the required parameter 'scriptPath' is set

      if (scriptPath === undefined || scriptPath === null) {
        throw new Error("Missing the required parameter 'scriptPath' when calling runScript");
      }

      var pathParams = {
        'scriptPath': scriptPath
      };
      var queryParams = {
        'params': this.apiClient.buildCollectionParam(opts['params'], 'csv')
      };
      var headerParams = {};
      var formParams = {};
      var authNames = [];
      var contentTypes = [];
      var accepts = ['application/json'];
      var returnType = _InlineResponse.default;
      return this.apiClient.callApi('/script/{scriptPath}', 'GET', pathParams, queryParams, headerParams, formParams, postBody, authNames, contentTypes, accepts, returnType, null, callback);
    }
  }]);

  return DefaultApi;
}();

exports.default = DefaultApi;