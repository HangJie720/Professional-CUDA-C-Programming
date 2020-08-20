Professional CUDA C Programming
===============================

1. Included in CodeSample/ are the code files for any samples used in the chapters as
illustrative examples.

Each chapter has its own code folder that includes the sample .c and .cu files
for that chapter. The per-chapter folders each also include a Makefile that can
be used to build the samples included.

2. Included in Solutions/ are solution text and code for each chapter's exercises.

The text solutions for every chapter is included in ExerciseSolutions.pdf.

Each chapter also has its own code folder that includes sample .c and .cu
code solutions for any exercises which require them. The per-chapter code
folders each also include a Makefile that can be used to build the solutions
included.

3. The common/ directory contains common.h, which includes code that is common to
multiple chapters.


Versions
===============================
June 14, 2015
- Fix bugs in reduction and transpose examples.
- Compile with -arch=sm_20 instead of the newer -arch=sm_30.
- Immediately exit on error.

January 16, 2015
- First version of all code samples.
