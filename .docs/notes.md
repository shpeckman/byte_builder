# WITH `taskset -c 0 ...`

## before

```

integers 0..255, 4096 per iteration
        IO::Memory <<  29.67k ( 33.70µs) (± 1.93%)  0.0B/op   5.19× slower
                  int  84.61k ( 11.82µs) (± 2.00%)  0.0B/op   1.82× slower
                 int3 124.16k (  8.05µs) (± 3.11%)  0.0B/op   1.24× slower
reserve + unsafe_int3 153.88k (  6.50µs) (± 2.65%)  0.0B/op        fastest

signed 32-bit integers of mixed length, 4096 per iteration
IO::Memory <<  16.54k ( 60.47µs) (± 5.61%)  0.0B/op   2.80× slower
          int  46.24k ( 21.63µs) (± 6.29%)  0.0B/op        fastest

unsigned 64-bit integers, 4096 per iteration
IO::Memory <<  11.85k ( 84.39µs) (± 0.65%)  0.0B/op   1.80× slower
          int  21.38k ( 46.78µs) (± 1.00%)  0.0B/op        fastest

hexadecimal and zero-padded integers, 4096 per iteration
          IO::Memory << to_s(16)  27.92k ( 35.82µs) (± 0.99%)  0.0B/op   1.89× slower
                             hex  52.72k ( 18.97µs) (± 1.22%)  0.0B/op        fastest
IO::Memory << to_s(precision: 3)  25.56k ( 39.12µs) (± 1.99%)  0.0B/op   2.06× slower
                        pad to 3  46.00k ( 21.74µs) (± 2.18%)  0.0B/op   1.15× slower

64-bit floats, 4096 per iteration
IO::Memory <<   4.80k (208.42µs) (± 0.87%)  0.0B/op   1.07× slower
          put   5.15k (194.34µs) (± 1.18%)  0.0B/op        fastest

short strings, 4096 per iteration
IO::Memory <<  50.55k ( 19.78µs) (± 1.70%)  0.0B/op   2.05× slower
          str 103.78k (  9.64µs) (± 1.67%)  0.0B/op        fastest
        bytes  95.94k ( 10.42µs) (± 3.13%)  0.0B/op   1.08× slower

characters of 1 to 4 bytes, 256 per iteration
        IO::Memory << 640.40k (  1.56µs) (± 0.77%)  0.0B/op   3.89× slower
                 char   2.49M (401.87ns) (± 2.71%)  0.0B/op        fastest
reserve + unsafe_char   2.10M (477.20ns) (± 5.90%)  0.0B/op   1.19× slower

characters of 1 to 4 bytes, 4096 per iteration
        IO::Memory <<  37.66k ( 26.55µs) (± 0.83%)  0.0B/op   3.80× slower
                 char 143.03k (  6.99µs) (±18.96%)  0.0B/op        fastest
reserve + unsafe_char 125.65k (  7.96µs) (±23.75%)  0.0B/op   1.14× slower

runs of 80 repeated characters, 256 per iteration
IO::Memory << ' ' * 80  30.95k ( 32.31µs) (± 1.28%)  0.0B/op   85.56× slower
          repeat ascii   2.65M (377.62ns) (± 1.33%)  0.0B/op         fastest
IO::Memory << '─' * 80   9.58k (104.43µs) (± 1.45%)  0.0B/op  276.55× slower
     repeat multi-byte 180.02k (  5.55µs) (± 0.34%)  0.0B/op   14.71× slower

growth from 16 bytes to 1 MiB
 IO::Memory   3.56k (281.13µs) (± 0.73%)  2.0MB/op   1.05× slower
ByteBuilder   3.75k (266.73µs) (± 0.70%)  2.0MB/op        fastest

cursor move and rgb colour, 256 per iteration
               interpolation + str  32.49k ( 30.78µs) (± 0.75%)  64.1kB/op   9.31× slower
                     IO::Memory <<  51.63k ( 19.37µs) (± 0.58%)    0.0B/op   5.86× slower
                   chained appends 252.08k (  3.97µs) (± 1.98%)    0.0B/op   1.20× slower
                           bbwrite 289.23k (  3.46µs) (± 0.58%)    0.0B/op   1.05× slower
           bbwrite with int3 hints 300.12k (  3.33µs) (± 1.93%)    0.0B/op   1.01× slower
                  defined template 302.32k (  3.31µs) (± 0.46%)    0.0B/op        fastest
bbwrite nesting a defined template 295.92k (  3.38µs) (± 0.65%)    0.0B/op   1.02× slower
                  runtime template  67.79k ( 14.75µs) (± 0.83%)    0.0B/op   4.46× slower

control string with optional fields, 256 per iteration
              interpolation + str  17.53k ( 57.06µs) (± 0.88%)  128kB/op  28.02× slower
                    chained field 391.73k (  2.55µs) (± 0.62%)   0.0B/op   1.25× slower
bbwrite with conditional branches 491.15k (  2.04µs) (± 0.55%)   0.0B/op        fastest
         bbwrite with field hints 487.42k (  2.05µs) (± 1.30%)   0.0B/op   1.01× slower

separated list of 8 strings, 256 per iteration
     interpolation + join  26.94k ( 37.12µs) (± 3.25%)  100kB/op   4.74× slower
chained appends in a loop 111.84k (  8.94µs) (± 1.27%)   0.0B/op   1.14× slower
        bbwrite with each 127.66k (  7.83µs) (± 1.91%)   0.0B/op        fastest

base64 of 48 bytes
    Base64.strict_encode to String  21.52M ( 46.46ns) (± 1.32%)  96.0B/op   2.74× slower
Base64.strict_encode to IO::Memory   3.65M (274.01ns) (± 2.00%)   0.0B/op  16.15× slower
                            base64  58.95M ( 16.96ns) (± 0.84%)   0.0B/op        fastest

base64 decoding of 48 bytes
Base64.decode to Bytes  21.58M ( 46.34ns) (± 0.81%)  64.0B/op   1.88× slower
              decode64  40.60M ( 24.63ns) (± 2.56%)   0.0B/op        fastest

base64 of 3072 bytes
    Base64.strict_encode to String 694.63k (  1.44µs) (± 1.03%)  4.03kB/op   1.89× slower
Base64.strict_encode to IO::Memory  62.51k ( 16.00µs) (± 0.52%)    0.0B/op  21.03× slower
                            base64   1.31M (760.81ns) (± 0.39%)    0.0B/op        fastest

base64 decoding of 3072 bytes
Base64.decode to Bytes 379.25k (  2.64µs) (± 1.17%)  3.02kB/op   2.12× slower
              decode64 805.41k (  1.24µs) (± 0.77%)    0.0B/op        fastest

base64 of 1048576 bytes
    Base64.strict_encode to String   2.48k (402.91µs) (± 0.95%)  1.34MB/op   1.50× slower
Base64.strict_encode to IO::Memory 178.05  (  5.62ms) (± 1.48%)    0.0B/op  20.84× slower
                            base64   3.71k (269.49µs) (± 2.69%)    0.0B/op        fastest

base64 decoding of 1048576 bytes
Base64.decode to Bytes   1.60k (625.80µs) (± 3.50%)  1.0MB/op   1.36× slower
              decode64   2.18k (458.71µs) (±12.50%)   0.0B/op        fastest
```

## after

```

integers 0..255, 4096 per iteration
        IO::Memory <<  27.81k ( 35.96µs) (± 2.58%)  0.0B/op   4.99× slower
                  int  86.43k ( 11.57µs) (± 2.23%)  0.0B/op   1.61× slower
                 int3 128.56k (  7.78µs) (± 1.28%)  0.0B/op   1.08× slower
reserve + unsafe_int3 138.88k (  7.20µs) (± 1.44%)  0.0B/op        fastest

signed 32-bit integers of mixed length, 4096 per iteration
IO::Memory <<  18.23k ( 54.86µs) (± 0.84%)  0.0B/op   2.83× slower
          int  51.58k ( 19.39µs) (± 1.31%)  0.0B/op        fastest

unsigned 64-bit integers, 4096 per iteration
IO::Memory <<  11.89k ( 84.09µs) (± 1.26%)  0.0B/op   1.77× slower
          int  21.09k ( 47.42µs) (± 1.36%)  0.0B/op        fastest

hexadecimal and zero-padded integers, 4096 per iteration
          IO::Memory << to_s(16)  28.23k ( 35.42µs) (± 0.66%)  0.0B/op   1.93× slower
                             hex  54.42k ( 18.38µs) (± 0.73%)  0.0B/op        fastest
IO::Memory << to_s(precision: 3)  25.55k ( 39.13µs) (± 0.49%)  0.0B/op   2.13× slower
                        pad to 3  47.49k ( 21.06µs) (± 0.77%)  0.0B/op   1.15× slower

64-bit floats, 4096 per iteration
IO::Memory <<   4.86k (205.78µs) (± 0.44%)  0.0B/op   1.06× slower
          put   5.14k (194.52µs) (± 1.70%)  0.0B/op        fastest

short strings, 4096 per iteration
IO::Memory <<  44.68k ( 22.38µs) (± 0.76%)  0.0B/op   2.44× slower
          str 108.94k (  9.18µs) (± 0.85%)  0.0B/op        fastest
        bytes 105.28k (  9.50µs) (± 0.84%)  0.0B/op   1.03× slower

characters of 1 to 4 bytes, 256 per iteration
        IO::Memory << 577.50k (  1.73µs) (± 1.17%)  0.0B/op   4.42× slower
                 char   2.54M (394.43ns) (± 0.56%)  0.0B/op   1.01× slower
reserve + unsafe_char   2.55M (392.15ns) (± 0.62%)  0.0B/op        fastest

characters of 1 to 4 bytes, 4096 per iteration
        IO::Memory <<  35.20k ( 28.41µs) (± 2.21%)  0.0B/op   4.77× slower
                 char 167.80k (  5.96µs) (± 1.12%)  0.0B/op        fastest
reserve + unsafe_char 165.76k (  6.03µs) (± 0.61%)  0.0B/op   1.01× slower

runs of 80 repeated characters, 256 per iteration
IO::Memory << ' ' * 80  31.69k ( 31.55µs) (± 1.29%)  0.0B/op   68.15× slower
          repeat ascii   2.16M (462.95ns) (± 1.40%)  0.0B/op         fastest
IO::Memory << '─' * 80   9.57k (104.51µs) (± 2.25%)  0.0B/op  225.75× slower
     repeat multi-byte 181.05k (  5.52µs) (± 0.68%)  0.0B/op   11.93× slower

growth from 16 bytes to 1 MiB
 IO::Memory   3.61k (276.66µs) (± 0.81%)  2.0MB/op   1.06× slower
ByteBuilder   3.83k (261.16µs) (± 0.55%)  2.0MB/op        fastest

cursor move and rgb colour, 256 per iteration
               interpolation + str  32.61k ( 30.66µs) (± 1.21%)  64.1kB/op   9.10× slower
                     IO::Memory <<  47.42k ( 21.09µs) (± 0.60%)    0.0B/op   6.26× slower
                   chained appends 244.94k (  4.08µs) (± 1.04%)    0.0B/op   1.21× slower
                           bbwrite 282.93k (  3.53µs) (± 0.35%)    0.0B/op   1.05× slower
           bbwrite with int3 hints 295.55k (  3.38µs) (± 0.67%)    0.0B/op   1.00× slower
                  defined template 296.79k (  3.37µs) (± 0.40%)    0.0B/op        fastest
bbwrite nesting a defined template 289.60k (  3.45µs) (± 0.39%)    0.0B/op   1.02× slower
                  runtime template  70.22k ( 14.24µs) (± 0.86%)    0.0B/op   4.23× slower

control string with optional fields, 256 per iteration
              interpolation + str  17.32k ( 57.75µs) (± 3.02%)  128kB/op  28.22× slower
                    chained field 389.12k (  2.57µs) (± 0.40%)   0.0B/op   1.26× slower
bbwrite with conditional branches 488.66k (  2.05µs) (± 0.52%)   0.0B/op        fastest
         bbwrite with field hints 484.50k (  2.06µs) (± 0.80%)   0.0B/op   1.01× slower

separated list of 8 strings, 256 per iteration
     interpolation + join  27.50k ( 36.36µs) (± 1.23%)  100kB/op   4.58× slower
chained appends in a loop 113.06k (  8.84µs) (± 0.64%)   0.0B/op   1.11× slower
        bbwrite with each 125.94k (  7.94µs) (± 0.79%)   0.0B/op        fastest

base64 of 48 bytes
    Base64.strict_encode to String  21.40M ( 46.73ns) (± 0.99%)  96.0B/op   3.28× slower
Base64.strict_encode to IO::Memory   3.34M (299.21ns) (± 0.52%)   0.0B/op  21.01× slower
                            base64  70.20M ( 14.24ns) (± 1.43%)   0.0B/op        fastest

base64 decoding of 48 bytes
Base64.decode to Bytes  21.18M ( 47.22ns) (± 2.51%)  64.0B/op   1.94× slower
              decode64  41.06M ( 24.35ns) (± 2.60%)   0.0B/op        fastest

base64 of 3072 bytes
    Base64.strict_encode to String 656.13k (  1.52µs) (± 0.75%)  4.03kB/op   2.63× slower
Base64.strict_encode to IO::Memory  57.05k ( 17.53µs) (± 0.73%)    0.0B/op  30.28× slower
                            base64   1.73M (578.77ns) (± 0.54%)    0.0B/op        fastest

base64 decoding of 3072 bytes
Base64.decode to Bytes 382.11k (  2.62µs) (± 1.75%)  3.02kB/op   2.10× slower
              decode64 804.23k (  1.24µs) (± 0.87%)    0.0B/op        fastest

base64 of 1048576 bytes
    Base64.strict_encode to String   2.49k (401.50µs) (± 0.88%)  1.34MB/op   2.01× slower
Base64.strict_encode to IO::Memory 161.94  (  6.18ms) (± 0.80%)    0.0B/op  30.99× slower
                            base64   5.02k (199.29µs) (± 2.00%)    0.0B/op        fastest

base64 decoding of 1048576 bytes
Base64.decode to Bytes   1.58k (632.81µs) (± 0.45%)  1.0MB/op   1.54× slower
              decode64   2.44k (410.14µs) (± 0.62%)   0.0B/op        fastest
```