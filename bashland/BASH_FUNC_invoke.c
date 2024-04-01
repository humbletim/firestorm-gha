// exe stub that proxies exported BASH_FUNC_ functions
// -- 2024.03.20 humbletim

// Purpose:
//  * Provides a mechanism to invoke Bash functions as if they were native executables.
//  * Addresses path manipulation issues encountered in environments like MSYS2 or Git Bash,
//    especially those occurring within CI/CD systems.

// Requirements:
//  * A MinGW-compatible C compiler (e.g., gcc)

// Compilation:
//  gcc BASH_FUNC_invoke.c -o BASH_FUNC_invoke.exe

// Usage:
// 1. **Create Bash functions:** Define your functions in your Bash environment. Example:
//    ```bash
//    function myutil() { echo "myutil... args=$@"; }
//    ```
// 2. **Export functions:** Export the functions to make them visible to subprocesses.
//    ```bash
//    declare -xf myutil
//    ```
//     This will create an environment variable named `BASH_FUNC_myutil%%`.
//     Note: it is also possible to export a regular string environment variable:
//           in the form `BASH_FUNC_myutil="... bash expression ..."`.
// 3. **Copy (or symlink) the stub:** Create copies or symlinks of `BASH_FUNC_invoke.exe`
//    giving them the names of your desired "executable" proxies (e.g., `misc/myutil.exe`).
// 4. **Adjust PATH:**  Ensure the directory containing your proxy executables has priority in your `PATH`.
//    ```bash
//    PATH="$PWD/misc:$PATH"
//    ```
// 5. **Invoke:** Call the proxy executable directly, as if it were a regular command.
//    ```bash
//    myutil.exe 1 "2 a" 3 # invoke via PATH (therefore available to any subsystem / subprocess)
//    myutil 1 "2 a" 3     # invoke as function (only available in bash subprocesses)
//    ```

// Notes:
//  * The `BASH_FUNC_...` environment variable defines the Bash code to execute.
//  * Arguments passed to the proxy are forwarded to the Bash function.

// Considerations:
//  * **Alternatives:** For less complex scenarios, consider Bash scripts or aliases within your CI/CD environment.
//  * **Debugging:**  Check the value of the `BASH_FUNC_...` variable and the constructed command string for troubleshooting.
//  *                 gcc -DDEBUG_COMMAND_STRING BASH_FUNC_invoke.c -o BASH_FUNC_invoke_debug.exe

// Let me know if you have any further questions or would like to add more specific usage examples!

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
// #include <unistd.h>
int execv(const char *pathname, char *const argv[]);

char *esc_dquotes(const char *arg);

int main(int argc, char *argv[]) {
    // Cross-platform basename extraction
    char *exe_name = strrchr(argv[0], '\\');
    if (exe_name == NULL) exe_name = strrchr(argv[0], '/');
    if (exe_name != NULL) exe_name++; else exe_name = argv[0];


    char name[128];
    strncpy(name, exe_name, sizeof(name));    
    // remove exstention
    char *dot = strrchr(name, '.');
    if (dot) *dot = 0;

    char command[4096];  // Adjust size if needed
    // craft command (eg: the 'func "$@"' of bash -c 'func "$@"' -- ..args)
    snprintf(command, sizeof(command), "%s \"$@\"", name);

    // Environment variable lookups
    char *bash_path = getenv("BASH");
#ifdef BASH
    if (bash_path == NULL) bash_path=BASH;
#endif
    if (bash_path == NULL) {
        fprintf(stderr, "Error: Environment variable 'BASH' not found.\n");
        return 1;
    }
    char func_env_name[256];  // Adjust size if needed
    snprintf(func_env_name, sizeof(func_env_name), "BASH_FUNC_%s%%%%", name);
    char *bash_command = command;
    char *bash_function = getenv(func_env_name);
    if (bash_function == NULL) {
      snprintf(func_env_name, sizeof(func_env_name), "BASH_FUNC_%s", name);
      bash_function = getenv(func_env_name);
      bash_command = bash_function;
    }
    if (bash_command == NULL || bash_function == NULL) {
        fprintf(stderr, "Error: Environment variable '%s' not found.\n", func_env_name);
        return 1;
    }
    if (argc >= 2 && argv[1] && strcmp(argv[1], "---version") == 0) {
      fprintf(stdout, "%s=%s\n%s\n", func_env_name, bash_function, bash_function == bash_command ? "" : bash_command); fflush(stdout); exit(0);
    }

    // Construct new argument list for execv
    char *new_argv[argc + 5]; // Account for 'bash', '-c', function command, '--' and NULL terminator
    new_argv[0] = bash_path;
    new_argv[1] = "-c";
    new_argv[2] = bash_command;
    new_argv[3] = exe_name;
    for (int i = 1; i < argc; i++) new_argv[i + 3] = argv[i];
    new_argv[argc + 3] = NULL; // Null terminator

    for (int i = 0; i < argc + 3; i++) new_argv[i] = esc_dquotes(new_argv[i]);
    new_argv[1] = "-c";

#if DEBUG_COMMAND_STRING
    for (int i = 0; i < argc + 4; i++) fprintf(stderr, "new_argv[%d]=%s\n", i, new_argv[i]); fflush(stderr);
#endif

    // Execute Bash using execv
    int e = execv(bash_path, new_argv);

    // Handle execv failure (this should generally not happen)
    fprintf(stderr, "execv failed %d\n", e);fflush(stderr);
    fprintf(stderr, "bash_path=%s\n", bash_path);fflush(stderr);
    for (int i = 0; i < argc + 4; i++) fprintf(stderr, "new_argv[%d]=%s\n", i, new_argv[i]); fflush(stderr);
    perror("execv failed");
    return 127; // A conventional error code to indicate execv failure
}


char *esc_dquotes(const char *arg) {
  // surplus quoting only necessary on mingw-windows (it seems)
#ifdef _WIN32
  const char DELIM = '"';
  char *escaped = malloc(strlen(arg) * 2 + 3); // Estimate: double chars, escaping, quotes
  if (escaped == NULL) return NULL;
  char *ptr = escaped;
  *ptr++ = DELIM; // Opening quote
  for (const char *p = arg; *p != '\0'; p++) {
    if (*p == DELIM) *ptr++ = '\\';
    *ptr++ = *p;
  }
  *ptr++ = DELIM; // Closing quote
  *ptr = '\0'; // Null terminate
#else
  char* escaped = strdup(arg);
#endif
  return escaped;
}
