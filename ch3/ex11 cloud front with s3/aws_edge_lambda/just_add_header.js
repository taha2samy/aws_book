'use strict';

exports.handler = (event, context, callback) => {
    const response = event.Records[0].cf.response;
    const headers = response.headers;
    headers['x-served-by'] = [{ key: 'X-Served-By', value: 'Lambda-Edge' }];
    headers['x-custom-message'] = [{ key: 'X-Custom-Message', value: 'This is from Taha' }];
    
    callback(null, response);
};