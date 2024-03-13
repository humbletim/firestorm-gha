// helper to invoke a script in full node20 actions environment
// -- humbletim 2024.03.13
 
const child_process = require('child_process');
// process.env.GITHUB_WORKSPACE && process.chdir(process.env.GITHUB_WORKSPACE);


var {
    INPUT_environment: environment,
    INPUT_inputs: inputs,
    INPUT_run: run,
    INPUT_shell: shell,
    "INPUT_working-directory": working_directory,
    GITHUB_WORKSPACE: workspace,
} = process.env;

console.debug('INPUT_', { inputs, run, shell, environment, workspace, working_directory })

if (!shell || shell == 'bash') {
    var bash_exe = process.env.PROGRAMFILES ? `${process.env.PROGRAMFILES}\\Git\\usr\\bin\\bash.exe` : 'bash';
    shell = `${bash_exe} --noprofile --norc -e -o pipefail {0}`
}


var args = shell.split(/ +/).filter((x)=> x !== '');
var idx = args.indexOf('{0}');
if (!~idx) throw new Error('{0} not found in '+shell);
args.splice(idx, 1, '-c', run);

var exe = args.shift();
var options = { stdio: 'inherit', env: {}, shell: false };
if (working_directory) options.cwd = working_directory;
else if (workspace) options.cwd = workspace;

var estr= environment || '';
(' '+estr).replace(/ ([-_0-9A-Za-z]+)=([^ ]+)/g, (_, k, v) => options.env[k]=v);

console.debug('... calling spawn', exe, args, options)

const bash = child_process.spawn(exe, args, options );
bash.on('exit', (c)=>{ console.log('exit code', c); process.exit(c); });

//////////////////////////////////////////////////////////////////////////////

// process.stdin.pipe(bash.stdin);
// bash.stdout.pipe(process.stdout);
// bash.stderr.pipe(process.stderr);


// var reps={};
// var n=0;
// function absorb(_, value) {
//     var key = `__xx__${n++}`;
//     reps[key]= value;
//     return ' '+key;
// }
// // handle escaped chars
// shell = ` ${shell} `; 
// console.log('before', shell)
// shell = shell.replace(/ "((?:[^"]+|\\")+)"/g, absorb);
// shell = shell.replace(/ ((?:[^ ]+\\ [^ ]+)+)/g, absorb)
// var args = shell.split(/ +/)
//   .map((x)=> x in reps ? reps[x] : x)
//   .filter((x)=> x !== '');
// console.log('reps', reps)
