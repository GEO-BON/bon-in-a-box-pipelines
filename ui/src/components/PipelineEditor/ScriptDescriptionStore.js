
const BonInABoxScriptService = require('bon_in_a_box_script_service');
const api = new BonInABoxScriptService.DefaultApi();

// Script descriptions do not change dynamically and should not trigger updates, hence this static store.
var descriptions = {}

/**
 * Returns local copy or performs remote call to get the metadata associated with the description file location.
 * @param {String} descriptionFileLocation 
 * @param {Function} callback function accepting metadata as a parameter, or null
 */
export function fetchStepDescription(descriptionFileLocation, callback) {
  let existingDescription = descriptions[descriptionFileLocation]
  if (existingDescription) {
    callback(existingDescription)
    return
  }

  // We know that Pipeline descriptions are json and Scripts are yaml...
  if(descriptionFileLocation.endsWith('.json')) {
    api.getPipelineInfo(descriptionFileLocation, (error, callbackData, response) => {
      if (error) {
        console.error("Error loading " + descriptionFileLocation + ":", error);
      } else {
        descriptions[descriptionFileLocation] = callbackData
        callback(callbackData)
      }
    });
  } else {
    api.getScriptInfo(descriptionFileLocation, (error, callbackData, response) => {
      if (error) {
        console.error("Error loading " + descriptionFileLocation + ":", error)
      } else {
        descriptions[descriptionFileLocation] = callbackData
        callback(callbackData)
      }
    });
  }
}

/**
 * Provided we know the metadata is already fetched, this immediately returns the metadata.
 * Otherwise it will return null without attempting to get the data.
 * @param {String} descriptionFileLocation 
 * @returns metadata, or null
 */
export function getStepDescription(descriptionFileLocation) {
  return descriptions[descriptionFileLocation]
}