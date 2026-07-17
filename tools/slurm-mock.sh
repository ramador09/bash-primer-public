# tools/slurm-mock.sh — a thin SLURM mock for "Introduction to the Bash Shell"
# (Notebook 16). Binder has no scheduler, so this stands in for one.
#
# What is REAL here
# -----------------
#   * `sbatch script.sh` reads the script's `#SBATCH` directives (they are
#     ordinary comments to bash, so the scripts students write are EXACTLY what
#     they would submit on Euler), runs the job body locally in the BACKGROUND,
#     and writes a real `slurm-<jobid>.out` in the current directory.
#   * The body runs in a FRESH, module-purged shell — a faithful stand-in for the
#     "fresh non-login shell on a compute node" that will NOT have your
#     interactively-loaded modules. This is what makes the Notebook-14 lesson
#     ("module load INSIDE the job") felt: a job that omits it fails; one that
#     includes it works.
#   * `--array=A-B` runs the body once per task with `$SLURM_ARRAY_TASK_ID` set,
#     writing `slurm-<jobid>_<task>.out` for each.
#   * `squeue` / `scancel` / `sacct` / `sinfo` behave plausibly off a small
#     per-session state directory.
#
# What is SIMULATED (the honest sidebar)
# --------------------------------------
#   The QUEUE WAIT. On a real cluster your job waits its turn among hundreds of
#   others; here it starts immediately. `srun` (interactive) is conceptual.
#
# Determinism for the build
# -------------------------
#   Job bodies run in the background, so a notebook reads `slurm-*.out` only AFTER
#   a `wait` (kept in a hidden cell). Job IDs come from a monotonic counter that
#   `slurm_hard_reset` seeds, so they are reproducible across builds even though
#   real Euler IDs vary — graded `check`s still test CONTENT, never IDs.
#
# Usage: `source tools/slurm-mock.sh` in the notebook's hidden setup cell (the
# same place `tools/check.sh` and the module system are set up).

# --- state -----------------------------------------------------------------
# Per kernel session, and OUTSIDE scratch/ so it survives the `rm -rf scratch`
# that resets each section. Job OUTPUT files (slurm-<id>.out) go to the current
# directory, exactly like real sbatch.
: "${SLURM_MOCK_HOME:=${TMPDIR:-/tmp}/bp-slurm-mock-$$}"
export SLURM_MOCK_HOME

_slurm_q() { printf '%s/queue'   "$SLURM_MOCK_HOME"; }
_slurm_a() { printf '%s/acct'    "$SLURM_MOCK_HOME"; }
_slurm_c() { printf '%s/counter' "$SLURM_MOCK_HOME"; }

_slurm_init() {                    # lazily create the state files
  mkdir -p "$SLURM_MOCK_HOME"
  [ -f "$(_slurm_c)" ] || printf '1000\n' > "$(_slurm_c)"
  [ -f "$(_slurm_q)" ] || : > "$(_slurm_q)"
  [ -f "$(_slurm_a)" ] || : > "$(_slurm_a)"
}

# Clear the queue + accounting between sections, but KEEP the job counter so IDs
# climb monotonically through the notebook (more realistic, still reproducible).
slurm_reset() { _slurm_init; : > "$(_slurm_q)"; : > "$(_slurm_a)"; }

# Full reset including the counter — call once, in the notebook's global setup.
slurm_hard_reset() { rm -rf "$SLURM_MOCK_HOME"; _slurm_init; }

_slurm_nextid() {
  _slurm_init
  local n; n=$(cat "$(_slurm_c)")
  printf '%s\n' "$((n + 1))" > "$(_slurm_c)"
  printf '%s\n' "$n"
}

# --- helpers ---------------------------------------------------------------
# Resolve an --output pattern (%j job id, %a array task, %A array job) to a file
# name; default to SLURM's own slurm-<id>.out / slurm-<id>_<task>.out.
_slurm_outfile() {                 # pattern jobid taskid
  local pat="$1" jid="$2" tid="$3"
  if [ -z "$pat" ]; then
    if [ -n "$tid" ]; then printf 'slurm-%s_%s.out\n' "$jid" "$tid"
    else                   printf 'slurm-%s.out\n'    "$jid"; fi
    return
  fi
  pat="${pat//%A/$jid}"; pat="${pat//%j/$jid}"; pat="${pat//%a/$tid}"
  printf '%s\n' "$pat"
}

# Run the job body in a FRESH, module-purged shell, capturing all output to the
# job's .out file. This is the heart of the env-inside-the-job lesson.
_slurm_run() {                     # script outfile jobid name taskid
  local script="$1" of="$2" jid="$3" nm="$4" tid="$5"
  (
    # A compute node would not have your login-shell modules: start clean.
    command -v module >/dev/null 2>&1 && module purge >/dev/null 2>&1
    export SLURM_JOB_ID="$jid" SLURM_JOB_NAME="$nm" SLURM_SUBMIT_DIR="$PWD"
    export SLURM_CPUS_ON_NODE=1
    if [ -n "$tid" ]; then
      export SLURM_ARRAY_JOB_ID="$jid" SLURM_ARRAY_TASK_ID="$tid"
    fi
    bash "$script"
  ) > "$of" 2>&1
}

_slurm_dequeue() {                 # jobid — drop a job's line from the queue
  local jid="$1" Q; Q="$(_slurm_q)"
  awk -F'|' -v j="$jid" '$1!=j' "$Q" > "$Q.tmp.$jid" 2>/dev/null && \
    mv "$Q.tmp.$jid" "$Q" 2>/dev/null || :
}

_slurm_setpid() {                  # jobid pid — fill in a queued job's bg pid
  local jid="$1" pid="$2" Q; Q="$(_slurm_q)"
  awk -F'|' -v OFS='|' -v j="$jid" -v p="$pid" '$1==j{$7=p}1' "$Q" \
    > "$Q.tmp.$jid" 2>/dev/null && mv "$Q.tmp.$jid" "$Q" 2>/dev/null || :
}

_slurm_killtree() {                # kill a pid and all its descendants (no orphans)
  local p="$1" c
  for c in $(pgrep -P "$p" 2>/dev/null); do _slurm_killtree "$c"; done
  kill "$p" 2>/dev/null
}

# --- the commands ----------------------------------------------------------

# sbatch — submit a batch script. Parses #SBATCH directives from the file (and
# matching command-line options), then runs the body (or array tasks) in the
# background and prints the job id.
sbatch() {
  _slurm_init
  local script="" name="" out="" array="" part=""
  local -a opts=()
  local a
  for a in "$@"; do
    case "$a" in
      *.sh) script="$a" ;;
      *)    opts+=("$a") ;;
    esac
  done
  if [ -z "$script" ] || [ ! -f "$script" ]; then
    printf 'sbatch: error: Unable to open file %s\n' "${script:-(no script given)}" >&2
    return 1
  fi

  # Gather #SBATCH directive tokens from the script, then the CLI options after
  # them (so a command-line option overrides a directive, as real sbatch does).
  local -a toks=()
  local line
  while IFS= read -r line; do
    # word-split each directive line into tokens (values carry no spaces)
    toks+=( $line )
  done < <(grep -E '^[[:space:]]*#SBATCH[[:space:]]' "$script" \
             | sed -E 's/^[[:space:]]*#SBATCH[[:space:]]+//')
  toks+=( "${opts[@]}" )

  local i n=${#toks[@]} t
  for ((i = 0; i < n; i++)); do
    t="${toks[i]}"
    case "$t" in
      --job-name=*)   name="${t#--job-name=}" ;;
      --job-name|-J)  name="${toks[i+1]}"; ((i++)) ;;
      --output=*)     out="${t#--output=}" ;;
      --output|-o)    out="${toks[i+1]}"; ((i++)) ;;
      --array=*)      array="${t#--array=}" ;;
      --array|-a)     array="${toks[i+1]}"; ((i++)) ;;
      --partition=*)  part="${t#--partition=}" ;;
      --partition|-p) part="${toks[i+1]}"; ((i++)) ;;
    esac
  done
  [ -z "$name" ] && name="$(basename "$script" .sh)"
  [ -z "$part" ] && part="normal"

  local jobid; jobid="$(_slurm_nextid)"
  local user="${USER:-$(id -un 2>/dev/null || echo user)}"
  # Enqueue (state R) BEFORE backgrounding, so an immediate `squeue` sees it.
  printf '%s|%s|%s|%s|R|0:01|-\n' "$jobid" "$name" "$user" "$part" >> "$(_slurm_q)"

  (
    if [ -n "$array" ]; then
      local lo hi tt
      lo="${array%%-*}"; hi="${array##*-}"; hi="${hi%%:*}"
      [ "$lo" = "$array" ] && hi="$lo"
      for ((tt = lo; tt <= hi; tt++)); do
        _slurm_run "$script" "$(_slurm_outfile "$out" "$jobid" "$tt")" "$jobid" "$name" "$tt"
      done
    else
      _slurm_run "$script" "$(_slurm_outfile "$out" "$jobid" "")" "$jobid" "$name" ""
    fi
    _slurm_dequeue "$jobid"
    printf '%s|%s|COMPLETED|0:0\n' "$jobid" "$name" >> "$(_slurm_a)"
  ) </dev/null >/dev/null 2>&1 &   # detach the job's stdio from the caller, so a
                                   # `$(sbatch ...)` does not block on the body's
                                   # pipe (job output already goes to its .out file)
  _slurm_setpid "$jobid" "$!"
  printf 'Submitted batch job %s\n' "$jobid"
}

# squeue — show the queue. Accepts and ignores the usual filters (-u, -j, --me),
# since the per-session queue is small and all yours.
squeue() {
  _slurm_init
  printf '%18s %11s %10s %9s %2s %8s %6s %s\n' \
         JOBID PARTITION NAME USER ST TIME NODES NODELIST
  local jid nm us part st tm pid
  while IFS='|' read -r jid nm us part st tm pid; do
    [ -z "$jid" ] && continue
    printf '%18s %11s %10s %9s %2s %8s %6s %s\n' \
           "$jid" "$part" "$nm" "$us" "$st" "$tm" 1 "compute-01"
  done < "$(_slurm_q)"
}

# scancel — cancel a job by id: kill its background body and record it cancelled.
scancel() {
  _slurm_init
  local jid="" a
  for a in "$@"; do case "$a" in -*) ;; *) jid="$a" ;; esac; done
  if [ -z "$jid" ]; then
    printf 'scancel: error: No job identification provided\n' >&2; return 1
  fi
  local Q nm pid; Q="$(_slurm_q)"
  nm=$(awk  -F'|' -v j="$jid" '$1==j{print $2}' "$Q")
  pid=$(awk -F'|' -v j="$jid" '$1==j{print $7}' "$Q")
  if [ -n "$pid" ] && [ "$pid" != "-" ]; then
    _slurm_killtree "$pid"; wait "$pid" 2>/dev/null
  fi
  _slurm_dequeue "$jid"
  printf '%s|%s|CANCELLED|0:0\n' "$jid" "${nm:-job}" >> "$(_slurm_a)"
}

# sacct — job accounting / history for this session.
sacct() {
  _slurm_init
  printf '%12s %12s %11s %8s\n' JobID JobName State ExitCode
  printf '%12s %12s %11s %8s\n' '------------' '------------' '-----------' '--------'
  local jid nm st ec
  while IFS='|' read -r jid nm st ec; do
    [ -z "$jid" ] && continue
    printf '%12s %12s %11s %8s\n' "$jid" "$nm" "$st" "$ec"
  done < "$(_slurm_a)"
}

# sinfo — a plausible static view of the cluster's partitions (Euler-flavoured).
sinfo() {
  cat <<'EOF'
PARTITION    AVAIL  TIMELIMIT  NODES  STATE
normal.4h       up    4:00:00     48  idle
normal.24h      up   24:00:00     96  mix
normal.120h     up  120:00:00     24  alloc
EOF
}
