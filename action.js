console.log(process.env.ACTIONS_CACHE_URL)
require('@actions/core').setOutput('ACTIONS_CACHE_URL', ACTIONS_CACHE_URL)
require('@actions/core').exportVariable('ACTIONS_CACHE_URL', ACTIONS_CACHE_URL)
