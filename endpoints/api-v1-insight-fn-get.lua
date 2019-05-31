--#ENDPOINT GET /api/v1/insight/{fn}
request.function_id = request.parameters.fn
local resp = require('insight').infoInsight(request)
return resp
