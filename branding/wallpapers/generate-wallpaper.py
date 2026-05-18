#!/usr/bin/env python3
"""
Generate the default namdevOS wallpaper as an SVG file.
Creates a dark gradient background with namdevOS branding text.
"""

import os

SVG_CONTENT = """<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080" viewBox="0 0 1920 1080">
  <defs>
    <linearGradient id="bg-gradient" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#1a1a2e;stop-opacity:1" />
      <stop offset="50%" style="stop-color:#16213e;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#0f3460;stop-opacity:1" />
    </linearGradient>
    <radialGradient id="glow" cx="50%" cy="50%" r="50%">
      <stop offset="0%" style="stop-color:#e94560;stop-opacity:0.15" />
      <stop offset="100%" style="stop-color:#e94560;stop-opacity:0" />
    </radialGradient>
  </defs>

  <!-- Background gradient -->
  <rect width="1920" height="1080" fill="url(#bg-gradient)" />

  <!-- Subtle glow effect -->
  <ellipse cx="960" cy="540" rx="600" ry="400" fill="url(#glow)" />

  <!-- Decorative circuit-like lines -->
  <g stroke="#e94560" stroke-width="0.5" fill="none" opacity="0.3">
    <path d="M 100 200 L 300 200 L 350 250 L 500 250" />
    <path d="M 1420 800 L 1620 800 L 1670 850 L 1820 850" />
    <path d="M 200 900 L 400 900 L 420 880 L 600 880" />
    <path d="M 1500 180 L 1650 180 L 1680 210 L 1800 210" />
    <circle cx="300" cy="200" r="3" fill="#e94560" />
    <circle cx="500" cy="250" r="3" fill="#e94560" />
    <circle cx="1620" cy="800" r="3" fill="#e94560" />
    <circle cx="1820" cy="850" r="3" fill="#e94560" />
  </g>

  <!-- namdevOS text -->
  <text x="960" y="520" font-family="sans-serif" font-size="72" font-weight="bold"
        fill="#ffffff" text-anchor="middle" letter-spacing="4">
    namdevOS
  </text>

  <!-- Tagline -->
  <text x="960" y="580" font-family="sans-serif" font-size="20"
        fill="#a0a0b0" text-anchor="middle" letter-spacing="2">
    Built for Developers
  </text>

  <!-- Version indicator -->
  <text x="960" y="620" font-family="monospace" font-size="14"
        fill="#e94560" text-anchor="middle" opacity="0.8">
    v1.0
  </text>
</svg>"""


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_path = os.path.join(script_dir, "namdevos-default.svg")

    with open(output_path, "w", encoding="utf-8") as f:
        f.write(SVG_CONTENT.strip() + "\n")

    print(f"Wallpaper generated: {output_path}")


if __name__ == "__main__":
    main()
