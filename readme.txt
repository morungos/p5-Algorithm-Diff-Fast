Algorithm::Diff::Fast

This is an XS-based implementation of the Algorithm::Diff, developed into a 
complete drop-in replacement for Algorithm::Diff. 

This was originally developed because some large data sets cause significant
performance issues for Algorithm::Diff, which may take many hours to 
process large sequences. Existing XS tools appear to show different
performance issues, requiring extremely large amounts of memory for some
large test sets. 

The C code used in Algorithm::Diff::Fast was taken from libmba, originally
developed by Michael B. Allen, and released under the MIT license. The "low
level" functions in Algorithm::Diff::Fast are a rewrite of those in 
Algorithm::Diff to exploit this new core system. The object-oriented API
(which looks on the clunky side to me) is a straight port from Algorithm::Diff,
as this only uses a few lower-level functions. This has been done to allow
Algorithm::Diff::Fast to pass all the tests from Algorithm::Diff::Fast, with
the increased performance of an XS based core. 
