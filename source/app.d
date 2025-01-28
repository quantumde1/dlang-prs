//quantumde1 developed software, licensed under GNU GPLv3, all rights reserved

import prs.compress;
import prs.decompress;
import prs.estimate;
import prs.exports;

import std.stdio;
import std.file;
import std.array;

import raylib;
import gui.gui;

void app_decompress(string[] args) {
    string inputFile = args[2];
    string outputFile = args[3];
    //reads input file
    byte[] sourceData = cast(byte[]) std.file.read(inputFile);
    //decompressing to byte array from initially readed data
    byte[] decompressedData = decompress(sourceData);
    //writing data to file
    std.file.write(outputFile, decompressedData);
    //exit
    writeln("Unpack ended, data written to: ", outputFile);
    return;
}

void app_compress(string[] args) {
    string inputFile = args[2];
    string outputFile = args[3];
    byte[] sourceData = cast(byte[]) std.file.read(inputFile);
    byte[] compressedData = compress(sourceData);
    std.file.write(outputFile, compressedData);
    writeln("Pack ended, data written to: ", outputFile);
    return;
}

void helper(string app_name) {
    writeln("Usage: ", app_name, " <command> <PRS file> <output/input file>\n
    Commands:\n
    unpack/extract/--extract/-e - extracts file from PRS file to output file\n
    pack/archive/--archive/-a - archives input file into PRS file\n
    help/--help/-h - shows this help\n");
    return;
}

void main(string[] args)
{
    if (args.length != 4 && args[1] != "gui")
    {
        helper(args[0]);
        return;
    }

    switch (args[1]) {
        case "-h":
        case "--help":
        case "help":
            helper(args[0]);
            break;
        case "-e":
        case "unpack":
        case "extract":
        case "--extract":
            app_decompress(args);
            break;
        case "-a":
        case "--archive":
        case "archive":
        case "pack":
            app_compress(args);
            break;
        case "gui":
            mainUIDrawer();
            break;
        default:
            helper(args[0]);
            break;
    }
}

