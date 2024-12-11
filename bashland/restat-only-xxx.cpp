#include <iostream>
#include <filesystem>
#include <string>
#include <regex>
#include <system_error>

namespace fs = std::filesystem;
std::string get_tool_name(int argc, char* argv[]);
std::string get_artifact_name(int argc, char* argv[]);
int execute_real_tool(int argc, char* argv[]);
int pretend_real_tool(int argc, char* argv[]);

int main(int argc, char* argv[]) {
  auto tool_name = get_tool_name(argc, argv);
  auto artifact = get_artifact_name(argc, argv);
  auto FAUXBUILD = getenv("FAUXBUILD");
  if (FAUXBUILD) {
    if (0 == strcmp(FAUXBUILD, "touch") || fs::exists(artifact)) {
      std::cerr << "RESTAT-ONLY " << tool_name << " " << artifact << std::endl;
      return pretend_real_tool(argc, argv);
    } // else fallthru
    std::cerr << "//REAL-TOOL " << tool_name << " " << artifact << std::endl;
  }
  return execute_real_tool(argc, argv);
}

/////////////////////

std::string get_tool_name(int argc, char* argv[]) {
  char* tool_name = strrchr(argv[0], '-');
  if (tool_name == NULL) {
    tool_name = argv[0];
  } else {
    tool_name++;
  }
  tool_name = strtok(tool_name, ".");
  return tool_name;
}

std::string get_artifact_name(int argc, char* argv[]) {
  std::string artifact_filename;
  std::regex artifact_regex("[-/](?:Fo|out:)[ ]*([^ ]+)");
  std::cmatch match;

  for (int i = 1; i < argc; ++i) {
    if (std::regex_search(argv[i], match, artifact_regex)) {
      return match[1].str();
    }
  }
  std::cerr << "Error: Could not find artifact filename in command line.\n";
  return {};
}

char *esc_dquotes(const char *arg) {
  // surplus quoting only necessary on mingw-windows (it seems)
#ifdef _WIN32
  const char DELIM = '"';
  char *escaped = (char*)malloc(strlen(arg) * 2 + 3); // Estimate: double chars, escaping, quotes
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

extern "C" int execv(const char *pathname, char *const argv[]);
char *esc_dquotes(const char *arg);
int execute_real_tool(int argc, char* argv[]) {
  auto tool_name = get_tool_name(argc, argv);
  char env_var_name[256];
  snprintf(env_var_name, sizeof(env_var_name), "_%s_exe", tool_name.c_str());
  // Retrieve the actual tool path from the environment
  char* tool_path = getenv(env_var_name);
  if (tool_path == NULL) {
    std::cerr << "Error: Environment variable " << env_var_name << " not found!\n";
    return 1;
  }
  // Prepare the argument list for execv
  char** execv_args = new char*[argc + 1];
  execv_args[0] = esc_dquotes(tool_path);
  for (int i = 1; i < argc; ++i) execv_args[i] = esc_dquotes(argv[i]);
  execv_args[argc] = nullptr;

  int result = execv(tool_path, execv_args);
  if (result == -1) {
    std::cerr << "Error executing " << tool_path << ": "
              << std::system_category().message(errno) << std::endl;
  }
  return 1;
}

int pretend_real_tool(int argc, char* argv[]) {
  auto artifact = get_artifact_name(argc, argv);
  // Construct and execute the touch command
  std::string touch_command = "touch.exe " + std::string{esc_dquotes(artifact.c_str())};
  // std::cerr << "TODO " << touch_command << std::endl; return 3;
  int result = std::system(touch_command.c_str());
  if (result != 0) {
    std::cerr << "Error executing " << touch_command << ": " << std::system_category().message(result) << std::endl;
    return 1;
  }
  return 0;
}
