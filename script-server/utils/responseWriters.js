function JsonResponse (payload, code = 200) {
  return {
    write: function (response) { 
      if (typeof payload === 'object') {
        payload = JSON.stringify(payload, null, 2);
      }
      response.writeHead(code, { 'Content-Type': 'application/json' });
      response.end(payload)
    }
  }
}

function TextResponse (payload, code = 200) {
  return {
    write: function (response) { 
      response.writeHead(code, { 'Content-Type': 'text/plain' });
      response.end(payload)
    }
  }
}

exports.JsonResponse = JsonResponse;
exports.TextResponse = TextResponse;