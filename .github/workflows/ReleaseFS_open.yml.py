#!/usr/bin/env python3
import os
import sys
import glob
import shlex
from collections import Counter, defaultdict

# --- CONFIGURATION ---
BUILD_ROOT = "build-vc170-64"

# Path Abstractions: (Anchor -> Variable Replacement)
# We scan for these anchors in order. First match wins.
PATH_VARS = [
    ("/indra/", "$source/"),
    ("/packages/", "$packages/"),
    (f"/{BUILD_ROOT.lower()}/", "$build/"),
]

# Flags that are known to accept an argument separated by a space
# e.g. /D _UNICODE or /I "path/to/include"
# We act "greedy" with these: if we see one, we peek at the next token.
GREEDY_FLAGS = {
    '/D', '/I', '/EXTERNAL:I', 
    '/Fo', '/FO', '/Fd', '/FD', '/Fe', '/FE', '/FI', '/Fi', '/Fp', '/FP', 
    '/YC', '/YU',
}

class PathSanitizer:
    @staticmethod
    def clean_path(path_str):
        if not path_str: return ""
        # 1. Normalize Slashes & Case
        s = path_str.replace("\\", "/").lower()
        # 2. Variable Substitution
        for anchor, variable in PATH_VARS:
            idx = s.find(anchor)
            if idx != -1:
                suffix = s[idx+len(anchor):] 
                return f"{variable}{suffix}"
        return s

    @staticmethod
    def format_flag(flag, value=None):
        """
        Recombines flag and value into a standardized string.
        Option: '/D _UNICODE' (Standardized spacing)
        """
        # If the flag itself contained the value (e.g. /D_UNICODE), 'value' is None
        # We need to split them if we want to normalize the path inside.
        
        # But our tokenizer splits them for us. 
        # So 'flag' is the switch (/I) and 'value' is the payload (path).
        
        if value is None:
            return flag
            
        # Clean the value (it might be a path or a macro)
        # We only strictly normalize paths, but lowercasing macros is risky?
        # User accepted '/D _UNICODE', so we won't lowercase the macro value, only paths.
        
        is_path_flag = flag.upper().startswith(("/I", "/EXTERNAL:I", "/FO", "/FD", "/FI", "/YC", "/YU"))
        
        if is_path_flag:
            cleaned_val = PathSanitizer.clean_path(value)
        else:
            # It's a Define or Option, keep strict fidelity for the value
            cleaned_val = value

        # Smart Quote: Only quote if space exists in the cleaned value
        if " " in cleaned_val:
            return f'{flag} "{cleaned_val}"'
        else:
            return f'{flag} {cleaned_val}'

class CompileUnit:
    def __init__(self, raw_source, raw_args):
        # Clean source path for display
        full_clean = PathSanitizer.clean_path(raw_source.strip())
        self.name = full_clean.replace("$source/", "").replace("$build/", "")
        self.flags = self._process_flags(raw_args)

    def _process_flags(self, arg_string):
        # 1. Basic Tokenization using shlex to respect quotes
        # windows paths with backslashes can confuse shlex, so we escape them first? 
        # Actually, tlog usually quotes paths with spaces. 
        # Let's try a simple split first, but respecting quotes is hard without shlex.
        # Fallback: simple split by space, then repair quotes?
        # Given the "no spaces in filenames" constraint, simple split is safe IF quotes are balanced.
        
        # However, "D:\foo bar" exists in Windows. 
        # Let's use a custom generator that handles quoted strings.
        
        tokens = []
        current_token = []
        in_quote = False
        
        for char in arg_string:
            if char == '"':
                in_quote = not in_quote
                current_token.append(char)
            elif char == ' ' and not in_quote:
                if current_token:
                    tokens.append("".join(current_token))
                    current_token = []
            else:
                current_token.append(char)
        if current_token:
            tokens.append("".join(current_token))
            
        # 2. Stateful Parsing (combining greedy flags)
        final_flags = []
        i = 0
        while i < len(tokens):
            token = tokens[i]
            
            # Check if this token is a flag
            if token.startswith("/") or token.startswith("-"):
                # Clean quotes from the flag itself if present
                clean_token = token.replace('"', '')
                upper_token = clean_token.upper()
                
                # Case 1: /Flag"Value" or /FlagValue (Value attached)
                # We need to detect if the value is already inside
                # Heuristic: If length > 2 and it's /D... or /I...
                
                # But wait, we want to handle `/D _UNICODE`
                # If clean_token is EXACTLY in GREEDY_FLAGS, look ahead.
                
                if upper_token in GREEDY_FLAGS:
                    # It is a bare flag like /D. Check next token.
                    if i + 1 < len(tokens) and not tokens[i+1].startswith(("/", "-")):
                        # Next token is the argument
                        arg = tokens[i+1].replace('"', '') # Strip quotes from arg
                        final_flags.append(PathSanitizer.format_flag(clean_token, arg))
                        i += 2 # Skip both
                        continue
                    else:
                        # No argument follows, or next is a flag. 
                        # Treat as bare flag? Or error? usually /D needs arg.
                        # Assuming attached like /D_UNICODE but token split failed?
                        final_flags.append(token)
                        i += 1
                        continue
                
                # Case 2: Attached value (/I"Path")
                # We need to split it to sanitize the path part
                found_attached = False
                for greedy in GREEDY_FLAGS:
                    if upper_token.startswith(greedy) and len(upper_token) > len(greedy):
                        # It has attached data
                        val = clean_token[len(greedy):]
                        final_flags.append(PathSanitizer.format_flag(clean_token[:len(greedy)], val))
                        found_attached = True
                        break
                
                if not found_attached:
                    # Just a normal flag (e.g. /W3, /nologo)
                    final_flags.append(token)
                    
                i += 1
            else:
                # Token doesn't start with / or - ... weird. 
                # Probably a source file or loose artifact. Ignore or log?
                i += 1
                
        return sorted(final_flags)

def load_tlogs():
    units = []
    pattern = os.path.join(BUILD_ROOT, "**", "CL.command.*.tlog")
    files = glob.glob(pattern, recursive=True)
    
    print(f"[*] Found {len(files)} TLOG files in {BUILD_ROOT}...")
    files = [ f for f in files if not ( 'plugin' in f or 'webrtc' in f or 'cmake' in f) ]
    print(f"[**] (pruned plugin|webrtc|cmake) Found {len(files)} TLOG files in {BUILD_ROOT}...")

    for fpath in files:
        try:
            with open(fpath, 'r', encoding='utf-16') as f: content = f.read()
        except UnicodeError:
            with open(fpath, 'r', encoding='utf-8', errors='ignore') as f: content = f.read()
                
        lines = content.splitlines()
        current_source = None
        for line in lines:
            line = line.strip()
            if not line: continue
            if line.startswith('^'):
                current_source = line[1:]
            elif current_source:
                units.append(CompileUnit(current_source, line))
                current_source = None
                
    print(f"[*] Parsed {len(units)} total compilation units.")
    return units

def mode_audit(units):
    if not units: return

    total = len(units)
    flag_counts = Counter()
    for u in units: flag_counts.update(u.flags)
        
    threshold = total * 0.95
    standard_flags = {f for f, c in flag_counts.items() if c > threshold}
    
    print(f"\n=== STANDARD CONFIGURATION ({len(standard_flags)} flags) ===")
    
    def sort_key(x):
        u = x.upper()
        if u.startswith("/D"): return (0, x)
        if u.startswith("/I") or "INCLUDE" in u: return (1, x)
        return (2, x)
        
    for f in sorted(standard_flags, key=sort_key):
        print(f"  {f}")

    print("\n=== DEVIATION REPORT ===")
    
    deviation_groups = defaultdict(list)
    for u in units:
        added = [f for f in u.flags if f not in standard_flags]
        dropped = [f for f in standard_flags if f not in u.flags]
        
        # Filter noise (Output paths)
        meaningful_added = []
        for f in added:
            u_f = f.upper()
            if not (u_f.startswith("/FO") or u_f.startswith("/FD")):
                meaningful_added.append(f)
        
        if meaningful_added or dropped:
            sig = (tuple(sorted(meaningful_added)), tuple(sorted(dropped)))
            deviation_groups[sig].append(u.name)

    print(f"Found {len(deviation_groups)} unique deviation signatures.")
    
    sorted_groups = sorted(deviation_groups.items(), key=lambda x: len(x[1]), reverse=True)
    
    for (added, dropped), filenames in sorted_groups:
        example_count = 3
        examples = filenames[:example_count]
        remaining = len(filenames) - example_count
        
        print(f"\n--- Group: {len(filenames)} files")
        print(f"    (e.g. {', '.join(examples)}" + (f", ...)" if remaining > 0 else ")"))
        
        if added:
            print(f"  + ADDED:")
            for f in added: print(f"      {f}")
        if dropped:
            print(f"  - MISSING:")
            for f in dropped: print(f"      {f}")

def mode_inspect(units, pattern):
    matches = [u for u in units if pattern.lower() in u.name.lower()]
    if not matches:
        print(f"No matches for '{pattern}'")
        return

    target = matches[0]
    print(f"\n=== INSPECTION: {target.name} ===")
    
    defines = []
    includes = []
    options = []
    
    for f in target.flags:
        u = f.upper()
        if u.startswith("/D"): defines.append(f)
        elif u.startswith(("/I", "/EXTERNAL:I")): includes.append(f)
        else: options.append(f)

    print("\n[DEFINES]")
    for f in sorted(defines): print(f"  {f}")

    print("\n[INCLUDES]")
    for f in sorted(includes): print(f"  {f}")

    print("\n[OPTIONS]")
    for f in sorted(options): print(f"  {f}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 audit_compiler_v7.py [audit|inspect <filename>]")
        sys.exit(1)

    all_units = load_tlogs()
    command = sys.argv[1]
    if command == "audit":
        mode_audit(all_units)
    elif command == "inspect":
        mode_inspect(all_units, sys.argv[2] if len(sys.argv) > 2 else "")
