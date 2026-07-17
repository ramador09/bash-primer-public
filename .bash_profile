# Login shells (ttyd launches `bash -l`) read this file, not ~/.bashrc directly.
# Source ~/.bashrc so the course prompt and settings apply in the live terminal.
[ -f ~/.bashrc ] && . ~/.bashrc
