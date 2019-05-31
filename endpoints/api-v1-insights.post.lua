--#ENDPOINT POST /api/v1/insights
local resp = require('insight').listInsights()
return resp
