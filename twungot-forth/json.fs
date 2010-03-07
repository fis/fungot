\ JSON decoder

require buf.fs
require map.fs

\ JSON error exceptions

s" JSON parse error" exception constant json-parse-error
s" JSON type error" exception constant json-type-error

\ JSON object type and helpers

0 constant json-type-bool
1 constant json-type-int
2 constant json-type-float
3 constant json-type-string
4 constant json-type-object
5 constant json-type-array

struct
    8 16 field json-data
    cell% field json-type
end-struct json%

json% %alloc
dup json-data true swap !
dup json-type json-type-bool swap !
constant json-true

json% %alloc
dup json-data false swap !
dup json-type json-type-bool swap !
constant json-false

: json-make ( data type -- obj )
    json% %alloc             \ data type obj
    dup json-type rot swap ! \ data obj
    dup json-data rot swap ! ;

: json-2make ( data1 data2 type -- obj )
    json% %alloc             \ data1 data2 type obj
    dup json-type rot swap ! \ data1 data2 obj
    dup json-data 2swap rot 2! ;

: json-fmake ( type -- obj ) ( F: data -- )
    json% %alloc             \ type obj  /  F: data
    dup json-type rot swap ! \ obj  /  F: data
    dup json-data f! ;

: json-negate ( value -- )
    dup json-type @ case
        json-type-int of
            dup json-data @ negate swap json-data ! endof
        json-type-float of
            dup json-data f@ fnegate json-data f! endof
        json-type-error throw
    endcase ;

defer json-dump

: json-dump-object-member ( value key-addr key-u -- )
    type ."  => " json-dump ." ," cr ;

: json-dump-object ( object -- )
    ." [OBJECT:" cr
    json-data @ ['] json-dump-object-member swap map-iterate
    ." ]" ;

: json-dump-array ( array -- )
    ." [ARRAY:" cr
    json-data 2@ 0 ?do dup @ json-dump ." ," cr cell+ loop drop
    ." ]" ;

:noname ( value -- )
    dup json-type @ case
        json-type-bool of json-data @ if ." TRUE" else ." FALSE" endif endof
        json-type-int of json-data @ . endof
        json-type-float of json-data f@ f. endof
        json-type-string of ." [" json-data 2@ type ." ]" endof
        json-type-object of json-dump-object endof
        json-type-array of json-dump-array endof
        json-type-error throw
    endcase ;
is json-dump

\ recursive-descent JSON parser

: json-getchar ( c-addr1 u1 -- c-addr2 u2 char )
    dup 0<= if json-parse-error throw endif
    1- swap dup 1+ -rot c@ ;

: json-?getchar ( c-addr1 u1 -- c-addr2 u2 char )
    dup if json-getchar else -1 endif ;

: json-ungetchar ( c-addr1 u1 char -- c-addr2 u2 )
    rot 1- dup -rot c! swap 1+ ;

: json-isblank ( char -- flag )
    case
        0x09 of true endof
        0x0a of true endof
        0x0d of true endof
        0x20 of true endof
        false swap
    endcase ;

: json-trim ( c-addr1 u1 -- c-addr2 u2 char )
    begin json-getchar dup json-isblank while drop repeat ;

: json-eat-string ( c-addr1 u1 c-addrC uC -- c-addr2 u2 )
    2over 2over string-prefix? 0= if json-parse-error throw endif
    nip /string ;

defer json-parse-string
defer json-parse-number
defer json-parse-object
defer json-parse-array

: json-parse-value ( c-addr1 u1 -- c-addr2 u2 value )
    json-trim
    dup 0x30 0x3a within if json-ungetchar json-parse-number exit endif
    case
        0x22 of json-parse-string endof
        0x2d of json-parse-number json-negate endof
        0x7b of json-parse-object endof
        0x5b of json-parse-array endof
        0x74 of s" rue" json-eat-string json-true endof
        0x66 of s" alse" json-eat-string json-false endof
        0x6e of s" ull" json-eat-string 0 endof
        json-parse-error throw
    endcase ;

: json-parse ( c-addr u -- value )
    json-parse-value -rot \ value c-addr2 u2
    -trailing nip         \ value left-over-chars
    if json-parse-error throw endif ;

: json-parse-string-escape-hex ( c-addr1 u1 -- c-addr2 u2 char )
    0 4 0 ?do                                       \ c-addr u num
        -rot json-getchar                           \ num c-addr u char
        dup 0x30 < if json-parse-error throw endif
        dup 0x30 0x3a within if 0x30 - endif
        dup 0x41 0x47 within if 0x37 - endif
        dup 0x61 0x67 within if 0x57 - endif
        dup 0x30 >= if json-parse-error throw endif \ num c-addr u digit
        3 roll 16 * +                               \ c-addr u new-num
    loop ;

: json-parse-string-escape ( c-addr1 u1 -- c-addr2 u2 char )
    json-getchar case
        0x22 of 0x22 endof \   " -> quotation mark
        0x5c of 0x5c endof \   \ -> reverse solidus
        0x2f of 0x2f endof \   / -> solidus
        0x62 of 0x08 endof \   b -> backspace
        0x66 of 0x0c endof \   f -> formfeed
        0x6e of 0x0a endof \   n -> newline
        0x72 of 0x0d endof \   r -> carriage return
        0x74 of 0x09 endof \   t -> horizontal tab
        0x75 of json-parse-string-escape-hex endof
        json-parse-error throw
    endcase ;

: json-parse-string-char ( c-addr1 u1 -- c-addr2 u2 char )
    json-getchar
    dup 0x20 < if json-parse-error throw endif
    case
        0x22 of -1 endof
        0x5c of json-parse-string-escape endof
        dup
    endcase ;

: json-parse-string-body ( c-addr u1 -- c-addr2 u2 str-addr str-u )
    0 buf-new { buf }
    begin
        json-parse-string-char
        dup 0>=
    while buf swap buf-append to buf repeat
    drop                 \ c-addr2 u2
    buf buf-count strdup \ c-addr2 u2 str-addr str-u
    buf free throw ;

:noname ( c-addr1 u1 -- c-addr2 u2 string )
    json-parse-string-body json-type-string json-2make ;
is json-parse-string

: json-parse-object-member ( c-addr1 u1 -- c-addr2 u2 value key-addr key-u )
    json-parse-string-body 2swap \ key-addr key-u c-addr c-u
    json-trim 0x3a <> if json-parse-error throw endif
    json-parse-value -rot        \ key-addr key-u value c-addr c-u
    json-trim case
        0x7d of 0x7d json-ungetchar endof
        0x2c of endof            \ , is expected here
        json-parse-error throw   \ something else
    endcase                      \ key-addr key-u value c-addr c-u
    rot 4 roll 4 roll ;

: json-parse-number-digits ( c-addr1 u1 -- c-addr2 u2 int )
    json-getchar 0x30 -                       \ c-addr u num
    dup 0 10 within 0= if json-parse-error throw endif
    -rot                                      \ num c-addr u
    begin
        json-?getchar dup 0x30 0x3a within    \ num c-addr u char/-1 flag
    while
            0x30 - 3 roll 10 * + -rot
    repeat                                    \ num c-addr u char/-1
    dup 0>= if json-ungetchar else drop endif \ num c-addr u
    rot ;

: json-parse-number-exp ( c-addr1 u1 -- c-addr2 u2 number ) ( F: mantissa -- )
    10e0                     \ c-addr u  /  F: mantissa 10e0
    json-getchar case
        0x2b of 1e0 endof
        0x2d of -1e0 endof
        json-ungetchar 1e0 0
    endcase                  \ c-addr u  /  F: mantissa 10e0 exp-sign
    json-parse-number-digits \ c-addr u exp-value  /  F: mantissa 10e0 exp-sign
    0 d>f f* f** f*          \ c-addr u  /  F: number
    json-type-float json-fmake ;

: json-parse-number-fraction ( int-part c-addr1 u1 -- c-addr2 u2 number )
    dup -rot                 \ int-part u1 c-addr u
    json-parse-number-digits \ int-part u1 c-addr u frac-part
    -rot dup 4 roll swap -   \ int-part frac-part c-addr u frac-len
    10e0 0 d>f fnegate f**   \ int-part frac-part c-addr u  /  F: multiplier
    rot 0 d>f f*             \ int-part c-addr u  /  F: frac-part
    rot 0 d>f f+             \ c-addr u  /  F: number
    json-?getchar
    dup 0x45 = over 0x65 = or if drop json-parse-number-exp exit endif
    dup 0>= if json-ungetchar else drop endif
    json-type-float json-fmake ;

:noname ( c-addr1 u1 -- c-addr2 u2 number )
    json-parse-number-digits -rot
    json-?getchar dup case
        0x2e of drop json-parse-number-fraction exit endof
        0x45 of drop rot 0 d>f json-parse-number-exp exit endof
        0x65 of drop rot 0 d>f json-parse-number-exp exit endof
    endcase
    dup 0>= if json-ungetchar else drop endif
    rot json-type-int json-make ;
is json-parse-number

:noname ( c-addr1 u1 -- c-addr2 u2 object )
    0 { map }
    begin json-trim dup 0x7d <>
    while
            0x22 <> if json-parse-error throw endif
            json-parse-object-member  \ c-addr u value key-addr key-u
            over 3 roll 3 roll 3 roll \ c-addr u key-addr value key-addr key-u
            map map-set to map        \ c-addr u key-addr
            free throw
    repeat
    drop map json-type-object json-make ;
is json-parse-object

:noname ( c-addr1 u1 -- c-addr2 u2 array )
    0 cellbuf-new { buf }
    begin json-trim dup 0x5d <>
    while
            json-ungetchar json-parse-value \ c-addr u value
            buf swap cellbuf-append to buf  \ c-addr u
            json-trim case
                0x5d of 0x5d json-ungetchar endof
                0x2c of endof
                json-parse-error throw
            endcase
    repeat
    drop
    buf buf-count arrdup json-type-array json-2make
    buf free throw ;
is json-parse-array
