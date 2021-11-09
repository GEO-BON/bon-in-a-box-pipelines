// Inspired from https://www.tutorialsteacher.com/nodejs/create-nodejs-web-server
var http = require('http'); // Import Node.js core module

var server = http.createServer(function (req, res) {   //create web server
    if (req.url == '/') { //check the URL of the current request
        
        // set response header
        res.writeHead(200, { 'Content-Type': 'text/html' }); 
        
        // set response content    
        res.write('<html><body><p>This is home Page.</p></body></html>');
        res.end();

        console.log('Welcome home!');
    
    }
    else if (req.url == "/student") {
        
        res.writeHead(200, { 'Content-Type': 'text/html' });
        res.write('<html><body><p>This is student Page.</p></body></html>');
        res.end();
    
    }
    else if (req.url == "/admin") {
        
        res.writeHead(200, { 'Content-Type': 'text/html' });
        res.write('<html><body><p>This is admin Page.</p></body></html>');
        res.end();
    
    }
    else
    {
        res.writeHead(404, { 'Content-Type': 'text/html' });
        res.write('<html><body><p>404 - Page not found</p></body></html>');
        res.end();
    }
});

server.listen(8080, function () {
        console.log('Listening on port 8080');
    }
);
