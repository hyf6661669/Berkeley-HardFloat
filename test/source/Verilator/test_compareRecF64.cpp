
/*============================================================================

This C++ source file is part of the Berkeley HardFloat IEEE Floating-Point
Arithmetic Package, Release 1, by John R. Hauser.

Copyright 2019 The Regents of the University of California.  All rights
reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice,
    this list of conditions, and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
    this list of conditions, and the following disclaimer in the documentation
    and/or other materials provided with the distribution.

 3. Neither the name of the University nor the names of its contributors may
    be used to endorse or promote products derived from this software without
    specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS "AS IS", AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, ARE
DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=============================================================================*/

#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <verilated.h>
#include "config.h"
#include "testCommon.h"
#include "VcompareRecF64.h"

/*----------------------------------------------------------------------------
*----------------------------------------------------------------------------*/

int main( int argc, char *argv[] )
{
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    int signaling, op;
    char *ptr;
    ptr = argv[1];
    if ( !ptr || !*ptr ) goto argsError;
    signaling = strtol( ptr, &ptr, 10 );
    if ( *ptr ) goto argsError;
    ptr = argv[2];
    if ( !ptr || !*ptr ) goto argsError;
    op = strtol( ptr, &ptr, 10 );
    if ( *ptr || (op < 0) || (2 < op) ) {
 argsError:
        fputs( "test-compareRecF64: Invalid arguments.\n", stderr );
        return EXIT_FAILURE;
    }
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    const char *opNamePtr = (op == 0) ? "lt" : (op == 1) ? "le" : "eq";
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
    fprintf(
        stderr,
        "Testing 'compareRecF64', signaling %d, op %s:\n",
        signaling,
        opNamePtr
    );
    VcompareRecF64 *modulePtr = new VcompareRecF64;
    modulePtr->signaling = signaling;
    long long errorCount = 0;
    long long count = 0;
    int partialCount = 0;
    for (;;) {
        /*--------------------------------------------------------------------
        *--------------------------------------------------------------------*/
        unsigned long long a, b;
        int expectOut, expectExceptionFlags;
        if (
            scanf(
                "%llx %llx %x %x", &a, &b, &expectOut, &expectExceptionFlags )
                < 4
        ) {
            break;
        }
        ++partialCount;
        if ( partialCount == 10000 ) {
            count += 10000;
            fprintf( stderr, "\r%7lld", count );
            partialCount = 0;
        }
        uint64_t recA[2], recB[2];
        f64ToRecF64( a, true, recA );
        f64ToRecF64( b, true, recB );
        /*--------------------------------------------------------------------
        *--------------------------------------------------------------------*/
        modulePtr->a[2] = recA[1];
        modulePtr->a[1] = recA[0]>>32;
        modulePtr->a[0] = recA[0];
        modulePtr->b[2] = recB[1];
        modulePtr->b[1] = recB[0]>>32;
        modulePtr->b[0] = recB[0];
        modulePtr->eval();
        int out =
              (op == 0) ? modulePtr->lt
            : (op == 1) ? modulePtr->lt || modulePtr->eq
            : modulePtr->eq;
        int exceptionFlags = modulePtr->exceptionFlags;
        if ( (out != expectOut) || (exceptionFlags != expectExceptionFlags) ) {
            fputc( '\r', stderr );
            if ( !errorCount ) {
                printf(
                    "Errors found in 'compareRecF64', signaling %d, op %s:\n",
                    signaling,
                    opNamePtr
                );
            }
            printf(
                "%X%016llX %X%016llX  => %X %02X  expected %X %02X\n",
                (unsigned int)recA[1],
                (unsigned long long)recA[0],
                (unsigned int)recB[1],
                (unsigned long long)recB[0],
                out,
                exceptionFlags,
                expectOut,
                expectExceptionFlags
            );
            ++errorCount;
            if ( errorCount == maxNumErrors ) {
                count += partialCount;
                goto errorStop;
            }
        }
    }
    count += partialCount;
    fputs( "\r                        \r", stderr );
    if ( errorCount ) goto errorStop;
    printf(
   "In %lld tests, no errors found in 'compareRecF64', signaling %d, op %s.\n",
        count,
        signaling,
        opNamePtr
    );
    return 0;
    /*------------------------------------------------------------------------
    *------------------------------------------------------------------------*/
 errorStop:
    fprintf(
        stderr, "--> In %lld tests, %lld errors found.\n", count, errorCount );
    return EXIT_FAILURE;

}

