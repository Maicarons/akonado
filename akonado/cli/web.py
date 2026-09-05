"""Launch web GUI command."""

from __future__ import annotations

import argparse


def cmd_web(args: argparse.Namespace) -> None:
    """Launch web GUI."""
    from ..config import WEB_DEBUG, WEB_HOST, WEB_PORT
    from ..web.app import create_app

    host = args.host or WEB_HOST
    port = args.port or WEB_PORT
    debug = args.debug or WEB_DEBUG

    app = create_app()
    print(f"[web] Starting akonado web GUI at http://{host}:{port}")
    app.run(host=host, port=port, debug=debug)
