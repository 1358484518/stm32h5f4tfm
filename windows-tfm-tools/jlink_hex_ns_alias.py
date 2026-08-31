#!/usr/bin/env python3
"""Intel HEX -> bin, map STM32 secure alias 0x0Cxxxxxx to 0x08xxxxxx (4 MB)."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from h5f4_win_images import main

if __name__ == "__main__":
    sys.exit(main())
