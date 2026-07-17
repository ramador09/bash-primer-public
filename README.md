# Introduction to the Bash Shell

A standalone, **physics-optional** course that teaches shell fluency from zero —
a leveling primer for students heading into computational science (and the
graduate Molecular and Materials Modelling course in particular). Part of the
same portfolio as [Elementary Computational Physics](https://github.com/ramador09/elementary-computational-physics-public)
and MMM.

This is the **private master** repo. It holds the worked solutions; a publish
workflow strips them and pushes the public site to `bash-primer-public`, which
serves GitHub Pages.

## How it is built

- **Jupyter Book** (Sphinx / MyST) → static site on GitHub Pages.
- Notebooks are **MyST-Markdown** (`.md`) with a **`bash_kernel`**: every code
  cell is real bash, executed at build time, its output captured.
- Validation is `tools/check.sh` — a sourced `check` function that fails the
  build on a wrong result (the bash analogue of a unit test).
- **Binder** gives students a real, throwaway bash terminal in the browser with
  the course data baked in — nothing to install.

See `CLAUDE.md` for the engineering contract, `NOTEBOOK_STYLE.md` for the voice
and pedagogy, and `manifest.yml` for the 17-notebook roadmap and status.

## Build locally

The book-build tooling is `requirements.txt` (pip); `environment.yml` is the
**Binder runtime** spec only (the GNU userland + the `ttyd` terminal stack), not
the build environment.

```bash
# build/validate environment (pip)
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python -m bash_kernel.install --sys-prefix

# convert, execute, and build
jupytext --to notebook notebooks/**/*.md
jupyter nbconvert --to notebook --execute --inplace \
    --ExecutePreprocessor.kernel_name=bash notebooks/**/*.ipynb
jupyter-book build .
# open _build/html/index.html
```

On macOS, put GNU coreutils ahead of the BSD tools so commands match Binder/CI:
`export PATH="$(brew --prefix coreutils)/libexec/gnubin:$PATH"`.

## Licence

Text CC BY 4.0 (`LICENSE-CONTENT`); code MIT (`LICENSE-CODE`). Course data is
republished MMM material — see `data/README.md`.
