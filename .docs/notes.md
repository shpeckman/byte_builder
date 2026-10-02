```
> crystal build --release --no-debug --progress bench/all.cr -o full_suite_before
> ./full_suite_before

integers 0..255, 256 per iteration
        IO::Memory << 492.96k (  2.03µs) (± 0.59%)  0.0B/op   4.98× slower
                  int   1.41M (710.62ns) (± 1.03%)  0.0B/op   1.75× slower
                 int3   1.90M (525.94ns) (± 0.89%)  0.0B/op   1.29× slower
reserve + unsafe_int3   2.46M (407.16ns) (± 0.43%)  0.0B/op        fastest

signed 32-bit integers of mixed length, 256 per iteration
IO::Memory << 335.19k (  2.98µs) (± 0.47%)  0.0B/op   2.61× slower
          int 876.34k (  1.14µs) (± 0.54%)  0.0B/op        fastest

unsigned 64-bit integers, 256 per iteration
IO::Memory << 201.66k (  4.96µs) (± 0.38%)  0.0B/op   1.63× slower
          int 329.54k (  3.03µs) (± 0.28%)  0.0B/op        fastest

short strings, 256 per iteration
IO::Memory << 850.24k (  1.18µs) (± 0.40%)  0.0B/op   2.19× slower
          str   1.86M (537.10ns) (± 2.16%)  0.0B/op        fastest
        bytes   1.79M (557.84ns) (± 2.86%)  0.0B/op   1.04× slower

characters of 1 to 4 bytes, 256 per iteration
        IO::Memory << 675.62k (  1.48µs) (± 1.72%)  0.0B/op   2.57× slower
                 char   1.10M (906.56ns) (± 4.39%)  0.0B/op   1.57× slower
reserve + unsafe_char   1.73M (576.86ns) (± 4.13%)  0.0B/op        fastest

growth from 16 bytes to 1 MiB
 IO::Memory   4.75k (210.43µs) (± 3.83%)  2.0MB/op   1.07× slower
ByteBuilder   5.10k (196.19µs) (± 5.09%)  2.0MB/op        fastest

cursor move and rgb colour, 256 per iteration
    interpolation + str  28.46k ( 35.14µs) (± 2.68%)  64.1kB/op  10.15× slower
          IO::Memory <<  52.80k ( 18.94µs) (± 1.04%)    0.0B/op   5.47× slower
        chained appends 259.74k (  3.85µs) (± 0.40%)    0.0B/op   1.11× slower
                bbwrite 275.11k (  3.63µs) (± 2.02%)    0.0B/op   1.05× slower
bbwrite with int3 hints 288.21k (  3.47µs) (± 1.13%)    0.0B/op   1.00× slower
       defined template 288.89k (  3.46µs) (± 0.32%)    0.0B/op        fastest

control string with optional fields, 256 per iteration
     interpolation + str  14.20k ( 70.41µs) (± 2.77%)  128kB/op  29.21× slower
           chained field 403.12k (  2.48µs) (± 0.46%)   0.0B/op   1.03× slower
bbwrite with field hints 414.83k (  2.41µs) (± 0.65%)   0.0B/op        fastest

base64 of 48 bytes
    Base64.strict_encode to String  17.21M ( 58.11ns) (± 4.31%)  96.0B/op   1.98× slower
Base64.strict_encode to IO::Memory   3.58M (279.39ns) (± 0.60%)   0.0B/op   9.52× slower
                            base64  34.08M ( 29.34ns) (± 0.36%)   0.0B/op        fastest

base64 of 3072 bytes
    Base64.strict_encode to String 732.47k (  1.37µs) (± 2.78%)  4.03kB/op        fastest
Base64.strict_encode to IO::Memory  60.31k ( 16.58µs) (± 0.70%)    0.0B/op  12.15× slower
                            base64 625.18k (  1.60µs) (± 0.87%)    0.0B/op   1.17× slower

base64 of 1048576 bytes
    Base64.strict_encode to String   2.01k (496.60µs) (± 3.62%)  1.34MB/op        fastest
Base64.strict_encode to IO::Memory 169.84  (  5.89ms) (± 0.83%)    0.0B/op  11.86× slower
                            base64   1.77k (566.15µs) (± 0.51%)    0.0B/op   1.14× slower
```

```
> crystal build --release --no-debug --progress bench/all.cr -o full_suite_after
> ./full_suite_after

integers 0..255, 4096 per iteration
        IO::Memory <<  28.72k ( 34.82µs) (± 0.74%)  0.0B/op   5.13× slower
                  int  86.08k ( 11.62µs) (± 3.07%)  0.0B/op   1.71× slower
                 int3 119.39k (  8.38µs) (± 1.06%)  0.0B/op   1.23× slower
reserve + unsafe_int3 147.32k (  6.79µs) (± 0.57%)  0.0B/op        fastest

signed 32-bit integers of mixed length, 4096 per iteration
IO::Memory <<  18.60k ( 53.76µs) (± 1.46%)  0.0B/op   2.84× slower
          int  52.78k ( 18.95µs) (± 2.16%)  0.0B/op        fastest

unsigned 64-bit integers, 4096 per iteration
IO::Memory <<  12.10k ( 82.62µs) (± 0.62%)  0.0B/op   1.87× slower
          int  22.62k ( 44.21µs) (± 0.92%)  0.0B/op        fastest

short strings, 4096 per iteration
IO::Memory <<  49.20k ( 20.32µs) (± 1.13%)  0.0B/op   2.27× slower
          str 111.81k (  8.94µs) (± 0.53%)  0.0B/op        fastest
        bytes 107.74k (  9.28µs) (± 0.39%)  0.0B/op   1.04× slower

characters of 1 to 4 bytes, 4096 per iteration
        IO::Memory <<  37.79k ( 26.46µs) (± 2.45%)  0.0B/op   3.60× slower
                 char  56.13k ( 17.82µs) (± 1.10%)  0.0B/op   2.42× slower
reserve + unsafe_char 136.02k (  7.35µs) (± 1.70%)  0.0B/op        fastest

growth from 16 bytes to 1 MiB
 IO::Memory   3.79k (263.66µs) (± 5.01%)  2.0MB/op   1.20× slower
ByteBuilder   4.54k (220.18µs) (± 4.82%)  2.0MB/op        fastest

cursor move and rgb colour, 256 per iteration
    interpolation + str  34.56k ( 28.93µs) (± 4.90%)  64.1kB/op   8.10× slower
          IO::Memory <<  51.06k ( 19.59µs) (± 1.68%)    0.0B/op   5.49× slower
        chained appends 250.94k (  3.99µs) (± 0.84%)    0.0B/op   1.12× slower
                bbwrite 268.94k (  3.72µs) (± 0.40%)    0.0B/op   1.04× slower
bbwrite with int3 hints 278.64k (  3.59µs) (± 0.41%)    0.0B/op   1.01× slower
       defined template 280.10k (  3.57µs) (± 0.90%)    0.0B/op        fastest

control string with optional fields, 256 per iteration
     interpolation + str  16.05k ( 62.32µs) (± 4.26%)  128kB/op  27.11× slower
           chained field 370.28k (  2.70µs) (± 0.35%)   0.0B/op   1.17× slower
bbwrite with field hints 435.04k (  2.30µs) (± 2.62%)   0.0B/op        fastest

base64 of 48 bytes
    Base64.strict_encode to String  18.89M ( 52.94ns) (± 4.70%)  96.0B/op   3.48× slower
Base64.strict_encode to IO::Memory   3.56M (280.75ns) (± 0.62%)   0.0B/op  18.45× slower
                            base64  65.71M ( 15.22ns) (± 1.90%)   0.0B/op        fastest

base64 of 3072 bytes
    Base64.strict_encode to String 707.75k (  1.41µs) (± 4.98%)  4.03kB/op   2.15× slower
Base64.strict_encode to IO::Memory  58.53k ( 17.09µs) (± 1.20%)    0.0B/op  26.04× slower
                            base64   1.52M (656.06ns) (± 0.70%)    0.0B/op        fastest

base64 of 1048576 bytes
    Base64.strict_encode to String   2.01k (497.08µs) (± 3.05%)  1.34MB/op   2.37× slower
Base64.strict_encode to IO::Memory 177.30  (  5.64ms) (± 0.64%)    0.0B/op  26.92× slower
                            base64   4.77k (209.54µs) (± 0.76%)    0.0B/op        fastest
```