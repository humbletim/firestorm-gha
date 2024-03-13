console.log(process.env.ACTIONS_CACHE_URL)
console.log('::add-mask::'+process.env.ACTIONS_CACHE_URL);
const fs = require("fs")
fs.appendFileSync(process.env.GITHUB_OUTPUT, `ACTIONS_CACHE_URL=${process.env.ACTIONS_CACHE_URL}\n`);
fs.appendFileSync(process.env.GITHUB_ENV, `ACTIONS_CACHE_URL=${process.env.ACTIONS_CACHE_URL}\n`);
  
