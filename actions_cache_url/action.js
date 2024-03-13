// console.log(process.env.ACTIONS_CACHE_URL)
console.log('::add-mask::'+process.env.ACTIONS_CACHE_URL);
// const fs = require("fs")
// fs.appendFileSync(process.env.GITHUB_OUTPUT, `ACTIONS_CACHE_URL=${process.env.ACTIONS_CACHE_URL}\n`);
// fs.appendFileSync(process.env.GITHUB_ENV, `ACTIONS_CACHE_URL=${process.env.ACTIONS_CACHE_URL}\n`);

const child_process = require('child_process');
process.chdir(process.env.GITHUB_WORKSPACE);

console.log('base', process.env.base)
console.log('foo', process.env.foo)
console.log('inputs', process.env.inputs)
console.log('inputs_json', process.env.inputs_json)

const bash = child_process.spawn(`${process.env.PROGRAMFILES}\\Git\\usr\\bin\\bash.exe`, ['fsvr/gha-bootstrap.sh']);
process.stdin.pipe(bash.stdin);
bash.stdout.pipe(process.stdout);
bash.stderr.pipe(process.stderr);
bash.on('exit', (c)=>{ console.log('exit code', c); process.exit(c); });
