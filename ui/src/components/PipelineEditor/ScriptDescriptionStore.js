
const yaml = require('js-yaml');
const BonInABoxScriptService = require('bon_in_a_box_script_service');
const api = new BonInABoxScriptService.DefaultApi();

// Script descriptions do not change dynamically and should not trigger updates, hence this static store.
var descriptions = {}

/**
 * Returns local copy or performs remote call to get the metadata associated with the description file location.
 * @param {String} descriptionFileLocation 
 * @param {Function} callback function accepting metadata as a parameter, or null
 */
export function fetchScriptDescription(descriptionFileLocation, callback) {
  let existingDescription = descriptions[descriptionFileLocation]
  if (existingDescription) {
    callback(existingDescription)
    return
  }

  api.getScriptInfo(descriptionFileLocation, (error, callbackData, response) => {
    if (error) {
      console.error("Error loading " + descriptionFileLocation + ": " + JSON.stringify(error))
      callback(null)
    } else {
      descriptions[descriptionFileLocation] = yaml.load(callbackData)
      callback(descriptions[descriptionFileLocation])
    }
  });
}