# Dlang PRS unpacker

Utility for unpacking Saturn or Dreamcast archives(.prs).
Written initially by Sewer56, maintained by quantumde1.

## GUI

Pretty straightforward and everything already in UI. For getting into dir, click on it, and for file select, click on it too.

## CLI

```
Usage: ./prs-decompressor-cli <command> <PRS file> <output/input file>

    Commands:

    unpack/extract/--extract/-e - extracts file from PRS file to output file

    pack/archive/--archive/-a - archives input file into PRS file

    help/--help/-h - shows this help

```

## Library

In C code, use apiCompress and apiDecompress functions. in D, compress and decompress can be used.

## FAQ

### What is it?

Answer: Utility for (pack/unpack)-ing Sega Enterprises Ltd(C) PRS archives. Everything works as excepted and sizes are equal to original files.

### Can it be used anywhere?

Answer: Why not? I guess, i'll use it in my NiGHTS-like game, made by raylib by @raysan5

### Why GUI so strange?

Its written in raylib, so its pretty lightweight, but not any beautiful, i know
