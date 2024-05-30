// helper to invoke a script in full node20 actions environment
// -- humbletim 2024.03.13

const child_process = require('child_process');

var {
    INPUT_environment: environment,
    // INPUT_env: env,
    INPUT_run: run,
    INPUT_shell: shell,
    INPUT_args: arguments,
    "INPUT_working-directory": working_directory,
    GITHUB_WORKSPACE: workspace,
} = process.env;

// console.debug('INPUT_', { run, shell, environment, workspace, working_directory })

shell = shell || 'bash';

const shells = {
  bash: process.env.PROGRAMFILES ? `${process.env.PROGRAMFILES}\\Git\\usr\\bin\\bash.exe` : 'bash',
  msys2: process.env.GHCUP_MSYS2 ? `${process.env.GHCUP_MSYS2}\\usr\\bin\\bash.exe` : 'msys2',
};
var cmd = shells[shell] ? `"${shells[shell]}" --noprofile --norc -e -o pipefail {0}` : shell;

var exe;
var args = cmd
    .replace(/^"([^\"]+)" |^([^ ]+) /, (_, a, b) => { exe=a || b; return ''; })
    .split(/ +/).filter(x=>x!=='');

var idx = args.indexOf('{0}');
if (!~idx) throw new Error('{0} not found in shell: '+shell);
if (/*INPUT_*/arguments) {
  run = 'eval "set -- ' + JSON.stringify(arguments).replace(/^"/,'').replace(/"$/, '')+ '";\n'+run;
}
args.splice(idx, 1, '-c', run);

// if (env) console.debug('INPUT_env', env);

var parsedEnv = (environment||'')
    .split(/\s*\n\s*/)
    .filter(x=>x.trim()!=='')
    .map((x)=>parseKeyValueString(x));
parsedEnv = Object.assign({}, ...parsedEnv);

var forwardEnv = {};
if (!parsedEnv['*'] || parsedEnv['*'] === 'process.env') Object.assign(forwardEnv, process.env);
else parsedEnv['*']
  .split(/[\s:,;]+/)
  .forEach((name) => {
    if (name in process.env) forwardEnv[name] = process.env[name];
  });

var options = {
    stdio: 'inherit',
    shell: false,
    cwd: working_directory || workspace || process.env.PWD,
    env: { ...forwardEnv, ...parsedEnv },
};

delete options.env['*'];
var tmp = JSON.parse(JSON.stringify(options));
if (parsedEnv['*'] !== 'none') tmp.env = '{ /* inherit process.env + parsed */ }';
if (process.env.DEBUG) console.debug('PARSED_', { exe: exe, args: JSON.stringify(args), options: tmp, forwardEnv: Object.keys(forwardEnv).length, parsedEnv: parsedEnv });

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
        if (!used) throw new Error(`parseKeyValueString error:\n\t[input] '${input}'\n\t[cur] '${str}'\n`)
        var [, key, value] = used;
        if (used === matches.dquoted) value = value.replace(/\\([\"])/g, '$1');
        if (used === matches.fallback) value = value.trim().replace(/\\ /g, ' ');
        result[key] = value;
        str = str.slice(used[0].length);
    }

    return result;
}
