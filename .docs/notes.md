```
> crystal build --release --no-debug --progress bench/all.cr -o bench_baseline
> ./bench_baseline

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
> crystal build --release --no-debug --progress bench/all.cr -o bench_opt_round_01
> ./bench_opt_round_01

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

```
> crystal build --release --no-debug --progress bench/all.cr -o bench_opt_round_02
> ./bench_opt_round_02

integers 0..255, 4096 per iteration
        IO::Memory <<  31.11k ( 32.15µs) (± 0.53%)  0.0B/op   5.13× slower
                  int  93.08k ( 10.74µs) (± 0.86%)  0.0B/op   1.71× slower
                 int3 118.47k (  8.44µs) (± 1.23%)  0.0B/op   1.35× slower
reserve + unsafe_int3 159.61k (  6.27µs) (± 1.13%)  0.0B/op        fastest

signed 32-bit integers of mixed length, 4096 per iteration
IO::Memory <<  19.59k ( 51.05µs) (± 0.77%)  0.0B/op   2.70× slower
          int  52.97k ( 18.88µs) (± 1.18%)  0.0B/op        fastest

unsigned 64-bit integers, 4096 per iteration
IO::Memory <<  12.35k ( 80.96µs) (± 1.40%)  0.0B/op   1.85× slower
          int  22.90k ( 43.67µs) (± 1.18%)  0.0B/op        fastest

short strings, 4096 per iteration
IO::Memory <<  51.02k ( 19.60µs) (± 0.73%)  0.0B/op   2.48× slower
          str 126.42k (  7.91µs) (± 0.39%)  0.0B/op        fastest
        bytes 118.25k (  8.46µs) (± 1.89%)  0.0B/op   1.07× slower

characters of 1 to 4 bytes, 256 per iteration
        IO::Memory << 670.49k (  1.49µs) (± 0.45%)  0.0B/op   3.20× slower
                 char   1.02M (982.19ns) (± 6.00%)  0.0B/op   2.11× slower
reserve + unsafe_char   2.15M (465.58ns) (± 3.30%)  0.0B/op        fastest

characters of 1 to 4 bytes, 4096 per iteration
        IO::Memory <<  39.96k ( 25.02µs) (± 0.59%)  0.0B/op   3.64× slower
                 char  60.94k ( 16.41µs) (± 3.37%)  0.0B/op   2.39× slower
reserve + unsafe_char 145.46k (  6.87µs) (± 2.47%)  0.0B/op        fastest

growth from 16 bytes to 1 MiB
 IO::Memory   5.71k (175.21µs) (± 5.16%)  2.0MB/op   1.07× slower
ByteBuilder   6.09k (164.11µs) (± 6.45%)  2.0MB/op        fastest

cursor move and rgb colour, 256 per iteration
    interpolation + str  28.84k ( 34.68µs) (± 1.58%)  64.1kB/op  10.10× slower
          IO::Memory <<  54.01k ( 18.52µs) (± 1.42%)    0.0B/op   5.39× slower
        chained appends 258.75k (  3.86µs) (± 0.36%)    0.0B/op   1.13× slower
                bbwrite 274.43k (  3.64µs) (± 1.05%)    0.0B/op   1.06× slower
bbwrite with int3 hints 288.79k (  3.46µs) (± 0.37%)    0.0B/op   1.01× slower
       defined template 291.19k (  3.43µs) (± 0.27%)    0.0B/op        fastest

control string with optional fields, 256 per iteration
     interpolation + str  14.81k ( 67.53µs) (± 4.56%)  128kB/op  32.30× slower
           chained field 410.32k (  2.44µs) (± 2.27%)   0.0B/op   1.17× slower
bbwrite with field hints 478.34k (  2.09µs) (± 0.49%)   0.0B/op        fastest

base64 of 48 bytes
    Base64.strict_encode to String  18.02M ( 55.48ns) (± 2.79%)  96.0B/op   3.70× slower
Base64.strict_encode to IO::Memory   4.00M (250.22ns) (± 0.62%)   0.0B/op  16.70× slower
                            base64  66.73M ( 14.98ns) (± 1.32%)   0.0B/op        fastest

base64 of 3072 bytes
    Base64.strict_encode to String 656.30k (  1.52µs) (± 6.25%)  4.03kB/op   2.30× slower
Base64.strict_encode to IO::Memory  71.54k ( 13.98µs) (± 1.93%)    0.0B/op  21.08× slower
                            base64   1.51M (663.24ns) (± 0.28%)    0.0B/op        fastest

base64 of 1048576 bytes
    Base64.strict_encode to String   1.66k (604.17µs) (± 2.58%)  1.34MB/op   2.91× slower
Base64.strict_encode to IO::Memory 209.49  (  4.77ms) (± 0.64%)    0.0B/op  22.99× slower
                            base64   4.82k (207.63µs) (± 0.62%)    0.0B/op        fastest
```

```
> crystal build --release --no-debug --progress bench/all.cr -o bench_opt_round_03
> ./bench_opt_round_03

integers 0..255, 4096 per iteration
        IO::Memory <<  28.22k ( 35.43µs) (±15.96%)  0.0B/op   4.98× slower
                  int  87.81k ( 11.39µs) (± 2.97%)  0.0B/op   1.60× slower
                 int3 125.46k (  7.97µs) (± 4.26%)  0.0B/op   1.12× slower
reserve + unsafe_int3 140.58k (  7.11µs) (±16.62%)  0.0B/op        fastest

signed 32-bit integers of mixed length, 4096 per iteration
IO::Memory <<  18.53k ( 53.98µs) (± 9.29%)  0.0B/op   2.75× slower
          int  50.95k ( 19.63µs) (± 1.58%)  0.0B/op        fastest

unsigned 64-bit integers, 4096 per iteration
IO::Memory <<  11.40k ( 87.69µs) (±13.83%)  0.0B/op   1.86× slower
          int  21.16k ( 47.25µs) (± 2.17%)  0.0B/op        fastest

hexadecimal and zero-padded integers, 4096 per iteration
          IO::Memory << to_s(16)  25.49k ( 39.23µs) (±13.67%)  0.0B/op   1.90× slower
                             hex  48.48k ( 20.63µs) (±22.75%)  0.0B/op        fastest
IO::Memory << to_s(precision: 3)  23.16k ( 43.18µs) (±22.44%)  0.0B/op   2.09× slower
                        pad to 3  45.20k ( 22.12µs) (± 2.46%)  0.0B/op   1.07× slower

64-bit floats, 4096 per iteration
IO::Memory <<   4.70k (212.98µs) (± 2.88%)  0.0B/op   1.06× slower
          put   4.97k (201.37µs) (± 2.46%)  0.0B/op        fastest

short strings, 4096 per iteration
IO::Memory <<  53.23k ( 18.79µs) (± 1.73%)  0.0B/op   2.12× slower
          str 112.67k (  8.88µs) (± 2.55%)  0.0B/op        fastest
        bytes 102.52k (  9.75µs) (±14.81%)  0.0B/op   1.10× slower

characters of 1 to 4 bytes, 256 per iteration
        IO::Memory << 529.68k (  1.89µs) (±26.11%)  0.0B/op   4.55× slower
                 char   2.41M (414.65ns) (± 3.19%)  0.0B/op        fastest
reserve + unsafe_char   2.21M (452.23ns) (±21.82%)  0.0B/op   1.09× slower

characters of 1 to 4 bytes, 4096 per iteration
        IO::Memory <<  39.47k ( 25.34µs) (± 5.14%)  0.0B/op   2.83× slower
                 char 111.66k (  8.96µs) (±13.00%)  0.0B/op        fastest
reserve + unsafe_char  88.14k ( 11.35µs) (± 5.95%)  0.0B/op   1.27× slower

runs of 80 repeated characters, 256 per iteration
IO::Memory << ' ' * 80  16.04k ( 62.36µs) (±16.97%)  0.0B/op   80.06× slower
          repeat ascii   1.28M (778.87ns) (± 1.64%)  0.0B/op         fastest
IO::Memory << '─' * 80   5.17k (193.31µs) (± 5.67%)  0.0B/op  248.19× slower
     repeat multi-byte  98.37k ( 10.17µs) (± 8.54%)  0.0B/op   13.05× slower

growth from 16 bytes to 1 MiB
 IO::Memory   1.80k (555.18µs) (±12.22%)  2.0MB/op   1.01× slower
ByteBuilder   1.81k (551.05µs) (±26.31%)  2.0MB/op        fastest

cursor move and rgb colour, 256 per iteration
               interpolation + str  10.79k ( 92.64µs) (± 6.50%)  64.0kB/op  16.24× slower
                     IO::Memory <<  43.36k ( 23.06µs) (±13.28%)    0.0B/op   4.04× slower
                   chained appends 166.87k (  5.99µs) (± 5.09%)    0.0B/op   1.05× slower
                           bbwrite 166.60k (  6.00µs) (± 2.10%)    0.0B/op   1.05× slower
           bbwrite with int3 hints 175.30k (  5.70µs) (± 8.74%)    0.0B/op        fastest
                  defined template 173.06k (  5.78µs) (± 1.67%)    0.0B/op   1.01× slower
bbwrite nesting a defined template 174.18k (  5.74µs) (± 1.54%)    0.0B/op   1.01× slower
                  runtime template  40.33k ( 24.80µs) (± 7.71%)    0.0B/op   4.35× slower

control string with optional fields, 256 per iteration
     interpolation + str   6.04k (165.47µs) (±11.07%)  128kB/op  54.18× slower
           chained field 298.32k (  3.35µs) (±13.89%)   0.0B/op   1.10× slower
bbwrite with field hints 327.47k (  3.05µs) (± 2.91%)   0.0B/op        fastest

base64 of 48 bytes
    Base64.strict_encode to String   6.83M (146.37ns) (±10.15%)  96.0B/op   5.63× slower
Base64.strict_encode to IO::Memory   2.92M (342.23ns) (±13.12%)   0.0B/op  13.17× slower
                            base64  38.48M ( 25.99ns) (± 2.73%)   0.0B/op        fastest

base64 decoding of 48 bytes
Base64.decode to Bytes   6.88M (145.30ns) (±26.76%)  64.0B/op   4.30× slower
              decode64  29.62M ( 33.76ns) (±10.59%)   0.0B/op        fastest

base64 of 3072 bytes
    Base64.strict_encode to String 247.86k (  4.03µs) (± 4.50%)  4.03kB/op   3.49× slower
Base64.strict_encode to IO::Memory  53.52k ( 18.68µs) (±21.83%)    0.0B/op  16.17× slower
                            base64 865.24k (  1.16µs) (± 3.70%)    0.0B/op        fastest

base64 decoding of 3072 bytes
Base64.decode to Bytes 104.24k (  9.59µs) (±10.12%)  3.02kB/op   5.60× slower
              decode64 583.96k (  1.71µs) (±18.55%)    0.0B/op        fastest

base64 of 1048576 bytes
    Base64.strict_encode to String 688.84  (  1.45ms) (±12.96%)  1.34MB/op   3.40× slower
Base64.strict_encode to IO::Memory 167.94  (  5.95ms) (±13.96%)    0.0B/op  13.94× slower
                            base64   2.34k (427.12µs) (± 6.47%)    0.0B/op        fastest

base64 decoding of 1048576 bytes
Base64.decode to Bytes 682.83  (  1.46ms) (±25.44%)  1.0MB/op   2.08× slower
              decode64   1.42k (703.17µs) (±10.57%)   0.0B/op        fastest
```