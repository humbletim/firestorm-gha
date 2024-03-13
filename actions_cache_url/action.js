// console.log(process.env.ACTIONS_CACHE_URL)
// console.log('::add-mask::'+process.env.ACTIONS_CACHE_URL);
// const fs = require("fs")
// fs.appendFileSync(process.env.GITHUB_OUTPUT, `ACTIONS_CACHE_URL=${process.env.ACTIONS_CACHE_URL}\n`);
// fs.appendFileSync(process.env.GITHUB_ENV, `ACTIONS_CACHE_URL=${process.env.ACTIONS_CACHE_URL}\n`);

const child_process = require('child_process');
process.chdir(process.env.GITHUB_WORKSPACE);
try {
let bash = child_process.spawn('/bin/bash', ['fsvr/gha-bootstrap.sh']);
} catch(e) {
console.error('/bin/bash no work; trying PROGRAMFILES', e);
 bash = child_process.spawn(`${process.env.PROGRAMFILES}\\Git\\usr\\bin\\bash.exe`, ['fsvr/gha-bootstrap.sh']);
}
process.stdin.pipe(bash.stdin);
bash.stdout.pipe(process.stdout);
bash.stderr.pipe(process.stderr);
bash.on('exit', (c)=> process.exit(c));
