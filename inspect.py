import sys

with open('pubspec.yaml','rb') as f:
    for i, line in enumerate(f, 1):
        sys.stdout.write(f"{i}: {line!r}\n")
