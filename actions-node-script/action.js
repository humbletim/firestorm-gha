// helper to invoke a script in full node20 actions environment
// -- humbletim 2024.03.13
 
const child_process = require('child_process');

var {
    INPUT_environment: environment,
    INPUT_run: run,
    INPUT_shell: shell,
    "INPUT_working-directory": working_directory,
    GITHUB_WORKSPACE: workspace,
} = process.env;

console.debug('INPUT_', { run, shell, environment, workspace, working_directory })

if (!shell || shell == 'bash') {
    var bash_exe = process.env.PROGRAMFILES ? `${process.env.PROGRAMFILES}\\Git\\usr\\bin\\bash.exe` : 'bash';
    shell = `"${bash_exe}" --noprofile --norc -e -o pipefail {0}`
}

var exe;
var args = shell
    .replace(/^"([^\"]+)" |^([^ ]+) /, (_, a, b) => { exe=a || b; return ''; })
    .split(/ +/).filter(x=>x!=='');

var idx = args.indexOf('{0}');
if (!~idx) throw new Error('{0} not found in shell: '+shell);
args.splice(idx, 1, '-c', run);

var parsedEnv = (environment||'')
    .split(/\s*\n\s*/)
    .filter(x=>x.trim()!=='')
    .map((x)=>parseKeyValueString(x));
parsedEnv = Object.assign({}, ...parsedEnv);

var forwardEnv = {};
(parsedEnv['*']||'').split(/[\s:,;]+/)
  .forEach((name) => {
    if (name === 'process.env') Object.assign(forwardEnv, process.env);
    else if (name in process.env) forwardEnv[name] = process.env[name];
  });

var options = {
    stdio: 'inherit',
    shell: false,
    cwd: working_directory || workspace || process.env.PWD,
    env: { ...forwardEnv, ...parsedEnv },
};

var tmp = JSON.parse(JSON.stringify(options));
if (parsedEnv['*'] === 'process.env') tmp.env = '{ /* inherit process.env + parsed */ }'; 
console.debug('PARSED_', { exe, args, options: tmp, forwardEnv: Object.keys(forwardEnv).length, parsedEnv: parsedEnv })

const bash = child_process.spawn(exe, args, options );

bash.on('exit', (c)=>{ console.log('exit code', c); process.exit(c); });

//////////////////////////////////////////////////////////////////////////////

function parseKeyValueString(input) {
    const regex = {
        dquoted: /^(?:^|\s)([^=\s]+)="((?:[^\\"]+|\\["\\])+)"/,
        squoted: /^(?:^|\s)([^=\s]+)='(.*?)'/,
        fallback: /^(?:^|\s)([^=\s]+)=((?:[^\\ ]+|\\[ ])+)/,
    };
    const result = {};

    str = input;
    while (str) {
        const prev = str;
        var matches = {};
        for (const [label, re] of Object.entries(regex)) {
            matches[label]=re.exec(str);
        }
        var used = matches.dquoted || matches.squoted || matches.fallback;
        if (!used) throw new Error(`parseKeyValueString error:\n\t[input] ${input}\n\t[cur] ${str}\n`)
        var [, key, value] = used;
        if (used === matches.dquoted) value = value.replace(/\\([\"])/g, '$1');
        if (used === matches.fallback) value = value.trim().replace(/\\ /g, ' ');
        result[key] = value;
        str = str.slice(used[0].length);
    }

    return result;
}

// console.log(parseKeyValueString("keyx=\"a value with spaces\" key2=value2 squot='c:\\Program Files' ekey=a\\ value\\ with\\ slashspaces anotherkey=complexvalue=weird other=\"embedded=\\\"super complex\\\"\""))
// process.exit(1);

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
