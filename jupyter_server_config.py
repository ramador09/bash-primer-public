# Jupyter Server config for the Binder image: register ttyd (a browser terminal)
# as a server proxied by jupyter-server-proxy, so launching Binder with
# `?urlpath=shell/` drops the student straight onto a full-page real bash
# terminal — no Jupyter chrome, no notebook.
#
# This file is copied to ~/.jupyter/jupyter_server_config.py by postBuild on the
# Binder image. It lives at the REPO ROOT (not in a binder/ directory) on
# purpose: repo2docker ignores root-level environment.yml / postBuild whenever a
# binder/ (or .binder/) directory exists, so we keep all build config at the root.
#
# See the "Binder full-page terminal — gotchas" section in CLAUDE.md.

c.ServerProxy.servers = {
    "shell": {  # path name 'shell', NOT 'terminal' (avoids Jupyter's /terminals/)
        "command": [
            "ttyd",
            "-W",            # writable: ttyd is READ-ONLY by default; without -W
                             # the terminal renders but rejects all typing.
            "-p", "{port}",  # jupyter-server-proxy substitutes a free port.
            "-b", "/shell",  # base path: must agree with absolute_url below.
            "-t", "fontSize=15",
            "bash", "-l",    # login shell: loads ~/.bash_profile -> ~/.bashrc
                             # (clean cwd-aware prompt); starts in $HOME (repo root).
        ],
        # Pass /shell/... through UNSTRIPPED so the proxied request path lines up
        # with `-b /shell`. (If the page ever loads blank or the websocket fails,
        # the alternate pairing is absolute_url=False + drop `-b` so ttyd serves
        # at root — see CLAUDE.md gotchas.)
        "absolute_url": True,
        "timeout": 60,
        "launcher_entry": {"enabled": True, "title": "Terminal"},
    }
}
