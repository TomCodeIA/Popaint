local process = require("@lune/process")
require("./unit")
local lib = require("./place")
if not lib.summary() then process.exit(1) end
