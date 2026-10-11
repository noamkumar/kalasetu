#!/usr/bin/env python3
"""Root proxy script for backend/scripts/check_ai.py."""
import sys
import subprocess
from pathlib import Path
import runpy

repo_root = Path(__file__).resolve().parent
if repo_root.name != "kala-setu" and (repo_root.parent / "backend").exists():
    repo_root = repo_root.parent

backend_dir = repo_root / "backend"
backend_check_ai = backend_dir / "scripts" / "check_ai.py"

# If running under a system Python without backend venv packages, re-exec with venv python
venv_py_win = backend_dir / ".venv" / "Scripts" / "python.exe"
venv_py_nix = backend_dir / ".venv" / "bin" / "python"
venv_py = venv_py_win if venv_py_win.exists() else (venv_py_nix if venv_py_nix.exists() else None)

if venv_py and Path(sys.executable).resolve() != venv_py.resolve():
    sys.exit(subprocess.call([str(venv_py), str(backend_check_ai)] + sys.argv[1:]))

if backend_check_ai.exists():
    if str(backend_dir) not in sys.path:
        sys.path.insert(0, str(backend_dir))
    runpy.run_path(str(backend_check_ai), run_name="__main__")
else:
    print(f"Error: Could not locate backend/scripts/check_ai.py at {backend_check_ai}", file=sys.stderr)
    sys.exit(1)

