"""
TypeFlow entry point.
Run with: python -m typeflow
"""

import sys
from .app import TypeFlowApplication


def main() -> int:
    """Main entry point for the TypeFlow application."""
    app = TypeFlowApplication()
    return app.run(sys.argv)


if __name__ == "__main__":
    sys.exit(main())
