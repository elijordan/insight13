--#ENDPOINT POST /api/v1/process
local resp = require('insight').process(request.body)
return resp
