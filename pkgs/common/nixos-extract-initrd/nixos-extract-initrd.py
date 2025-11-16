#!/usr/bin/env python3
"""
Extract NixOS initrd to a directory.

This script extracts multi-stage NixOS initrd images (microcode + zstd-compressed CPIO).
"""

import os
import sys
import subprocess
import argparse
from pathlib import Path


def find_current_initrd():
    """Find the current system's initrd path."""
    paths_to_check = [
        "/run/current-system/initrd",
        "/run/booted-system/initrd",
    ]

    for path in paths_to_check:
        if os.path.exists(path):
            # Resolve symlink
            real_path = os.path.realpath(path)
            print(f"Found initrd: {real_path}")
            return real_path

    return None


def find_zstd_offset(initrd_path):
    """Find the offset where ZSTD-compressed data starts."""
    zstd_magic = b'\x28\xb5\x2f\xfd'

    with open(initrd_path, 'rb') as f:
        data = f.read()
        offset = data.find(zstd_magic)

    if offset == -1:
        raise ValueError("ZSTD magic not found in initrd")

    return offset


def extract_initrd(initrd_path, output_dir):
    """Extract the initrd to the specified directory."""
    output_path = Path(output_dir)

    # Create output directory
    if output_path.exists():
        print(f"Removing existing directory: {output_path}")
        subprocess.run(['rm', '-rf', str(output_path)], check=True)

    output_path.mkdir(parents=True, exist_ok=True)
    os.chdir(output_path)

    print(f"Extracting to: {output_path}")

    # Find ZSTD offset
    print("Locating ZSTD compressed archive...")
    zstd_offset = find_zstd_offset(initrd_path)
    print(f"ZSTD archive starts at offset: {zstd_offset} bytes (0x{zstd_offset:x})")

    # Extract using dd + zstd + cpio pipeline
    print("Extracting initrd contents...")
    dd_cmd = ['dd', f'if={initrd_path}', 'bs=1', f'skip={zstd_offset}']
    zstd_cmd = ['zstd', '-d']
    cpio_cmd = ['cpio', '-idm', '--quiet', '--no-absolute-filenames']

    # Pipeline: dd | zstd -d | cpio -idm
    dd_proc = subprocess.Popen(dd_cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    zstd_proc = subprocess.Popen(zstd_cmd, stdin=dd_proc.stdout, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    dd_proc.stdout.close()  # Allow dd_proc to receive SIGPIPE if zstd_proc exits

    cpio_proc = subprocess.run(cpio_cmd, stdin=zstd_proc.stdout, capture_output=True, text=True)
    zstd_proc.stdout.close()

    # Wait for processes to complete
    dd_proc.wait()
    zstd_proc.wait()

    if cpio_proc.returncode != 0:
        print(f"Warning: cpio exited with code {cpio_proc.returncode}")
        if cpio_proc.stderr:
            print(f"cpio stderr: {cpio_proc.stderr}")

    print("\n✓ Extraction complete!")
    print("\nExtracted contents:")
    subprocess.run(['ls', '-lah', str(output_path)])

    print("\n/etc directory contents:")
    etc_path = output_path / 'etc'
    if etc_path.exists():
        subprocess.run(['ls', '-la', str(etc_path)])

    print(f"\nInitrd filesystem extracted to: {output_path}")


def main():
    parser = argparse.ArgumentParser(
        description='Extract NixOS initrd to a directory',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s                                    # Extract current system initrd to /tmp/initrd
  %(prog)s -o /tmp/my-initrd                  # Extract to custom directory
  %(prog)s -i /path/to/initrd -o /tmp/output  # Extract specific initrd file
        """
    )

    parser.add_argument(
        '-i', '--initrd',
        help='Path to initrd file (default: auto-detect current system)',
        default=None
    )

    parser.add_argument(
        '-o', '--output',
        help='Output directory (default: /tmp/initrd)',
        default='/tmp/initrd'
    )

    args = parser.parse_args()

    # Find initrd if not specified
    if args.initrd:
        initrd_path = args.initrd
        if not os.path.exists(initrd_path):
            print(f"Error: Initrd file not found: {initrd_path}", file=sys.stderr)
            sys.exit(1)
    else:
        initrd_path = find_current_initrd()
        if not initrd_path:
            print("Error: Could not find current system initrd", file=sys.stderr)
            print("Please specify initrd path with -i option", file=sys.stderr)
            sys.exit(1)

    try:
        extract_initrd(initrd_path, args.output)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
