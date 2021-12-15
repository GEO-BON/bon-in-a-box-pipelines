# BonInABoxScriptService.DefaultApi

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**getScriptInfo**](DefaultApi.md#getScriptInfo) | **GET** /info/{scriptPath} | Get metadata about this script
[**runScript**](DefaultApi.md#runScript) | **GET** /script/{scriptPath} | Run this script



## getScriptInfo

> String getScriptInfo(scriptPath)

Get metadata about this script

### Example

```javascript
import BonInABoxScriptService from 'bon_in_a_box_script_service';

let apiInstance = new BonInABoxScriptService.DefaultApi();
let scriptPath = "scriptPath_example"; // String | Where to find the script in ./script folder
apiInstance.getScriptInfo(scriptPath, (error, data, response) => {
  if (error) {
    console.error(error);
  } else {
    console.log('API called successfully. Returned data: ' + data);
  }
});
```

### Parameters


Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **scriptPath** | **String**| Where to find the script in ./script folder | 

### Return type

**String**

### Authorization

No authorization required

### HTTP request headers

- **Content-Type**: Not defined
- **Accept**: text/plain


## runScript

> InlineResponse200 runScript(scriptPath, opts)

Run this script

Run the script specified in the URL. Must include the extension.

### Example

```javascript
import BonInABoxScriptService from 'bon_in_a_box_script_service';

let apiInstance = new BonInABoxScriptService.DefaultApi();
let scriptPath = "scriptPath_example"; // String | Where to find the script in ./script folder
let opts = {
  'params': ["param1","param2"] // [String] | Additional parameters for the script
};
apiInstance.runScript(scriptPath, opts, (error, data, response) => {
  if (error) {
    console.error(error);
  } else {
    console.log('API called successfully. Returned data: ' + data);
  }
});
```

### Parameters


Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **scriptPath** | **String**| Where to find the script in ./script folder | 
 **params** | [**[String]**](String.md)| Additional parameters for the script | [optional] 

### Return type

[**InlineResponse200**](InlineResponse200.md)

### Authorization

No authorization required

### HTTP request headers

- **Content-Type**: Not defined
- **Accept**: application/json

