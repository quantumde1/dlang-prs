/*
	PRS-R (dlang-prs)
	
	A high performance custom compressor/decompressor for SEGA's
	PRS compression format used since the Sega Saturn.
	Copyright (C) 2018  Sewer. Sz (Sewer56)

	PRS-R is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	PRS-R is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program.  If not, see <https://www.gnu.org/licenses/>
 */

module prs.compress;

import std.algorithm;
import std.container.array;
import std.math; 
import std.typecons;

/*	
	---------------------
	Constants & Variables
	---------------------
 */ 

/** 
	Defines the maximum allowed length of matching/equivalent sequential bytes in a found pattern
	within the search buffer as part of the LZ77 compression algorithm PRS bases on.
	This value is inclusive, i.e. maxLength + 1 is the first disallowed value. 
 */
public const int maxLength = 0x100;

public const int shortCopyMaxLength = 0x100;
public const int shortCopyMaxOffset = 5;
public const int shortCopyMinOffset = 2;

/** 
	Defines the size of the sliding window to be used as part of LZ77
	offset and size based compression.
    The value listed here is the actual limit supported by the compression format.
	It may be overwritten by the parameter of the compress function.
 */
public int maxOffset = 0x1FFF;

/**
	Defines the index of the next control bit of the active control byte that is
	to be modified by the compressor in question.	
 */
private int currentBitPosition = 0;

/**
	Stores the current instance of the control byte which will have various variable length
	codes appended to it in order to instruct the decoder what to do next.
 */
private byte* controlByte;

/**
	Specifies the current offset from the start of the file used during compression.
 */
private int pointer = 0;

/*	
	------------------------
	Structs, Classes & Enums
	------------------------
 */ 

/** 
	Specifies the individual PRS modes of compression (opcodes) that
	may be used to encode the individual found LZ77 dictionary match.
 */
public enum CompressionType
{
	/** 
		The length of the copy if 2-5 inclusive and the maximum
		offset is 255 bytes.
	*/
	shortCopy,

	/**
		An offset (up to 0x1FFF) and size (3-9 inclusive) combination is written directly as 2 bytes
		to the array/file/stream with the offset taking 13 bits and size 3 bits. 
	*/
	longCopySmall,

	/**
		The same as longCopySmall except that the size is stored in another byte inside the controlByte-data
		block and is in the range 1-256
	*/
	longCopyLarge
}

/** 
	Defines a quick structure in the form of a tuple which
	declares the properties common to LZ77 compression algorithms.
 */
alias LZ77Properties = Tuple!(int, "offset", int, "length");

/**
	Compresses a supplied byte array.
	Returns the compressed version of the byte array.

	Params:
		source = The byte array containing the file or data to compress.

		searchBufferSize = (Default: 0x1FFF)
		                   A value preferably between 0xFF and 0x1FFF that declares how many bytes
		                   the compressor visit before any specific byte to search for matching patterns.
		                   Increasing this value compresses the data to smaller filesizes at the expense of compression time.
		                   Changing this value has no noticeable effect on decompression time.
 */
public byte[] compress(ref byte[] source, int searchBufferSize = 0x1FFF)
{
	// Assume our compressed file will be at least of equivalent length.
	auto destination = Array!byte();
	destination.reserve(cast(int)((source.length * 1.15F) + 3));

	// Theoretical worst scenario for PRS compression is 9/8, 112.5% size + 3 bytes
	// This is when every byte cannot get a copy back.
	// Just in case, I will be very generous and give 115%, + 3 bytes

	// Setup control byte.
	destination.insertBack(cast(byte) 0x00);
	controlByte = &destination[0];

	// Reset variables.
	pointer = 0;
	currentBitPosition = 0;
	maxOffset = searchBufferSize;

	// Begin compression.
	while (pointer < source.length)
	{
		// Find the longest match of repeating bytes.
		LZ77Properties lz77Match = lz77GetLongestMatch(source, pointer, searchBufferSize, maxLength);

		// Pack into the archive as direct byte if there is no match.
        if (lz77Match.offset >= -shortCopyMaxLength && lz77Match.length >= shortCopyMinOffset && lz77Match.length <= shortCopyMaxOffset)
        {
            pointer += lz77Match.length;
            writeShortCopy(destination, lz77Match); // CompressionType.shortCopy
        }
		else if (lz77Match.length <= 2)
		{
			writeDirectByte(destination, source[pointer]);
		}
		else
		{
            // Encode LZ77 Match
            pointer += lz77Match.length;
            if (lz77Match.length >= 3 && lz77Match.length <= 9)
                writeLongCopySmall(destination, lz77Match); // CompressionType.longCopySmall
            else
                writeLongCopyLarge(destination, lz77Match); // CompressionType.longCopyLarge	
		}
	}

	// Add finisher to PRS file.
	appendControlBit(0, destination);
	appendControlBit(1, destination);
	destination.insert(cast(byte)0x00);
	destination.insert(cast(byte)0x00);

	// Return back
	return (&destination[0])[0 .. destination.length].dup;
}

/** 
	Writes the direct byte opcode onto the control byte of the PRS
	compression buffer and its corresponding direct byte.
 */
pragma(inline, true)
public void writeDirectByte(ref Array!byte destinationArray, byte byteToWrite)
{
	appendControlBit(1, destinationArray);
	destinationArray.insert(byteToWrite);
	pointer += 1;
}


public void writeShortCopy(ref Array!byte destinationArray, ref LZ77Properties lz77Match)
{
	// Offset the size as required for this mode (pack 2-5 as 0-3)
	lz77Match.length -= 2;

	// Write opcode 00.
	appendControlBit(0, destinationArray);
	appendControlBit(0, destinationArray);

	// Pack the size with the second byte first.
	appendControlBit((lz77Match.length >> 1) & 1, destinationArray);
	appendControlBit(lz77Match.length & 1, destinationArray);

	// Write the offset as 256 - (offset * - 1) as required by the format.
	destinationArray.insert(cast(byte)(lz77Match.offset & 0xFF));
}

public void writeLongCopySmall(ref Array!byte destinationArray, ref LZ77Properties lz77Match)
{
	// Offset the size as required for this mode (pack 3-9 as 1-7)
	lz77Match.length -= 2;

	// Write opcode 01.
	appendControlBit(0, destinationArray);
	appendControlBit(1, destinationArray);

	// Pack the size into the short offset and write.
	short packed = cast(short)(((lz77Match.offset << 3) & 0xFFF8) | lz77Match.length);
	
	// Write the packed size and offset in Big Endian
	destinationArray.insert(cast(byte)packed);
	destinationArray.insert(cast(byte)(packed >> 8));
}

public void writeLongCopyLarge(ref Array!byte destinationArray, ref LZ77Properties lz77Match)
{
	// Offset the size as required for this mode.
	lz77Match.length -= 1;

	// Write opcode 01.
	appendControlBit(0, destinationArray);
	appendControlBit(1, destinationArray);

	// Pack the size into the short offset and write.
	short packed = cast(short)((lz77Match.offset << 3) & 0xFFF8);

	// Write the packed size and offset in Big Endian
	destinationArray.insert(cast(byte)packed);
	destinationArray.insert(cast(byte)(packed >> 8));

	// Write the offset.
	destinationArray.insert(cast(byte)lz77Match.length);
}

/**
	Digs through the search buffer and finds the longest match
	of repeating bytes which match the bytes at the current pointer
	onward.

	Params:
		source = Defines the array in which we will be looking for matches.
		pointer = Specifies the current offset from the start of the file used for matching symbols from.
		searchBufferSize = The amount of bytes to search backwards in order to find the matching pattern.
		maxLength = The maximum number of bytes to match in a found pattern searching backwards. This number is inclusive, i.e. includes the passed value.
	
 */
public LZ77Properties lz77GetLongestMatch(byte[] source, int pointer, int searchBufferSize, int maxLength)
{
	/*	The source bytes are a reference in order to prevent copying. 
		The other parameters are value type in order to take advantage of locality of reference.
	*/
	
	/** Stores the details of the best found LZ77 match up till a point. */
	LZ77Properties bestLZ77Match = LZ77Properties(0,0);

	/** The length of the current match of symbols. */
	int currentLength = 0;

	/** Set the minimum position the pointer can access. */
	int minimumPointerPosition = pointer - searchBufferSize;
	if (minimumPointerPosition < 0)
		minimumPointerPosition = 0;

    /** Speedup: If cannot exceed source length, do not check it on every loop iteration. (else clause) */
    if (pointer + maxLength + int.sizeof >= source.length) // length is 1 indexed, our reads are not.
    {
        for (int currentPointer = pointer - 1; currentPointer >= minimumPointerPosition; currentPointer--)
        {
            if (source[currentPointer] == source[pointer])
            {
                /* We've matched a symbol: Count matching symbols. */
                currentLength = 1;
                while ((pointer + currentLength < source.length) && (source[currentPointer + currentLength] == source[pointer + currentLength]))
                    currentLength++;
                
                /* 
                    Cap at the limit of repeated bytes if it's over the limit of what PRS allows.
                    We can also stop our search here.
                */
                if (currentLength > maxLength)
                {
                    currentLength = maxLength;
                    bestLZ77Match.length = currentLength;
                    bestLZ77Match.offset = currentPointer - pointer;
                    goto foundMaxLengthMatch;
                }

                /* Set the best match if acquired. */
                if (currentLength > bestLZ77Match.length)
                {
                    bestLZ77Match.length = currentLength;
                    bestLZ77Match.offset = currentPointer - pointer;
                }
            }
        }
    }
    else 
    {
        int initialMatch = (*cast(int*)(&source[pointer])) & 0x00FFFFFF;

        /** Iterate over each individual byte backwards to find the longest match. */
        for (int currentPointer = pointer - 1; currentPointer >= minimumPointerPosition; currentPointer--)
        {
            if ((*cast(int*)(&source[currentPointer]) & 0x00FFFFFF) == initialMatch)
            {
                /* We've matched a symbol: Count matching symbols. */
                currentLength = 3;
                while (source[currentPointer + currentLength] == source[pointer + currentLength])
                {
                    currentLength++;

                    /* 
						This check needs to be here, otherwise the search might go into unitialized memory as 
                        the loop will not cap before maxLength
                    */
                    if (currentLength > maxLength)
                    {
                        currentLength = maxLength;
                        bestLZ77Match.length = currentLength;
                        bestLZ77Match.offset = currentPointer - pointer;
                        goto foundMaxLengthMatch;
                    }
                }

                /*  Set the best match if acquired. */
                if (currentLength > bestLZ77Match.length)
                {
                    bestLZ77Match.length = currentLength;
                    bestLZ77Match.offset = currentPointer - pointer;
                }
            }
        }

        /* If no match found, check for possible missed short copy (2-5 bytes). */
        if (bestLZ77Match.length == 0) 
        {
            short shortInitialMatch = (*cast(short*)(&source[pointer]));
            minimumPointerPosition = pointer - min(searchBufferSize, shortCopyMaxLength);
            if (minimumPointerPosition < 0)
                minimumPointerPosition = 0;

            for (int currentPointer = pointer - 1; currentPointer >= minimumPointerPosition; currentPointer--)
            {
                if ((*cast(short*)(&source[currentPointer])) == shortInitialMatch)
                {
                    /* We've matched a symbol: Count matching symbols. */
                    currentLength = 2;
                    bestLZ77Match.length = currentLength;
                    bestLZ77Match.offset = currentPointer - pointer;
                    break;
                }
            }
        }
    }


	foundMaxLengthMatch:
	return bestLZ77Match;
}

/**
	Places an individual bit into the current index of the current control byte,
	then increments the current bit position denoted by variable currentBitPosition.

	Params:
		bit              = The either 0 or 1 bit to be appended onto the control byte.
		destinationArray = The array from which the individual control byte is sourced.
		                   Used for assigning the new control byte when necessary.
 */
public void appendControlBit(int bit, ref Array!byte destinationArray)
{
	/*
		All of the bit positions have been used up, we need to write the bit 
		and its the data for the block down.

		In this reference encoder we do the exhaustion check and flushing/writing
		of the block of opcodes (control byte) and data before writing the next
		opcode rather than after.
	
		This automatically ensures that the opcode and the next control byte lie
		in the same block as long as the order or writing the opcodes before their
		data block counterparts (which makes the source code cleaner and easier to 
		understand anyway) is enforced.
	 */
	if (currentBitPosition >= 8)                                      
	{
		// Setup next control byte.
		destinationArray.insertBack(cast(byte) 0x00);
		controlByte = &destinationArray[destinationArray.length - 1];

		// Reset offset.
		currentBitPosition = 0;
	}

	// Append the current bit position and go to next position.
	*controlByte |= (bit << currentBitPosition);
	currentBitPosition++;
}
