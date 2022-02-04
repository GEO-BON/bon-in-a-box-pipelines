# BonInABoxScriptService.DefaultApi

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**getScriptInfo**](DefaultApi.md#getScriptInfo) | **GET** /script/{scriptPath}/info | Get metadata about this script
[**runScript**](DefaultApi.md#runScript) | **POST** /script/{scriptPath}/run | Run this script
[**scriptListGet**](DefaultApi.md#scriptListGet) | **GET** /script/list | Get a list of available scripts



## getScriptInfo

> String getScriptInfo(scriptPath)

Get metadata about this script

### Example

```javascript
import BonInABoxScriptService from 'bon_in_a_box_script_service';

let apiInstance = new BonInABoxScriptService.DefaultApi();
let scriptPath = "scriptPath_example"; // String | Where to find the script in ./script folder.
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
 **scriptPath** | **String**| Where to find the script in ./script folder. | 

### Return type

**String**

### Authorization

No authorization required

### HTTP request headers

- **Content-Type**: Not defined
- **Accept**: text/plain


## runScript

> ScriptRunResult runScript(scriptPath, opts)

Run this script

Run the script specified in the URL. Must include the extension.

### Example

```javascript
import BonInABoxScriptService from 'bon_in_a_box_script_service';

let apiInstance = new BonInABoxScriptService.DefaultApi();
let scriptPath = "scriptPath_example"; // String | Where to find the script in ./script folder
let opts = {
  'body': '{ 
              "occurence":"/output/result/from/previous/script", 
              "intensity":3
            } ' // String | Content of input.json for this run
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
 **body** | **String**| Content of input.json for this run | [optional] 

### Return type

[**ScriptRunResult**](ScriptRunResult.md)

### Authorization

No authorization required

### HTTP request headers

- **Content-Type**: text/plain
- **Accept**: application/json


## scriptListGet

> [String] scriptListGet()

Get a list of available scripts

### Example

```javascript
import BonInABoxScriptService from 'bon_in_a_box_script_service';

let apiInstance = new BonInABoxScriptService.DefaultApi();
apiInstance.scriptListGet((error, data, response) => {
  if (error) {
    console.error(error);
  } else {
    console.log('API called successfully. Returned data: ' + data);
  }
});
```

### Parameters

This endpoint does not need any parameter.

### Return type

**[String]**

### Authorization

No authorization required

### HTTP request headers

- **Content-Type**: Not defined
- **Accept**: application/json

