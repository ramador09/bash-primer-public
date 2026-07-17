# Course shell defaults for the Binder terminal. A clean, cwd-aware prompt that
# models the prompt slated to debut in Notebook 2 and matches the `\w $` console
# convention used in the lessons. Sourced via ~/.bash_profile (ttyd runs a login
# shell). Non-interactive shells (the bash_kernel) do not read this, so the
# notebook build is unaffected.
PS1='\w \$ '

# Sane history behaviour for an interactive practice session.
export HISTCONTROL=ignoreboth
shopt -s histappend 2>/dev/null || true

# Cluster practice (Notebooks 14 & 16): make the real module system and the SLURM
# stand-in work in THIS terminal too, exactly as in the rendered notebook cells.
# ttyd starts a login shell in $HOME (the repo root), so the demo modulefiles,
# stub software, and tools/ all live under $HOME here. The bash_kernel does not
# read this file (it sets these up in each notebook's hidden setup cell instead).
export MODULES_PAGER=cat            # short demo list; no pager (matches the cells)
for _init in /usr/share/modules/init/bash /etc/profile.d/modules.sh; do
  [ -r "$_init" ] && { . "$_init"; break; }
done
if command -v module >/dev/null 2>&1 && [ -d "$HOME/modulefiles" ]; then
  module use "$HOME/modulefiles"    # democode/1.0, democode/2.0, analysis-tools/3.2
fi
# The SLURM mock (sbatch/squeue/scancel/sacct/sinfo) for Notebook 16 practice.
[ -r "$HOME/tools/slurm-mock.sh" ] && . "$HOME/tools/slurm-mock.sh"
