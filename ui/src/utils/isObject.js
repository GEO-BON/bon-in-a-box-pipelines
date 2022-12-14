// Based on https://bobbyhadz.com/blog/javascript-check-if-value-is-object
function isObject(variable) {
    return typeof variable === 'object' &&
        variable !== null &&
        !Array.isArray(variable)
}

export default isObject
