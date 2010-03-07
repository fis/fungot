\ flexible-size auto-allocated byte buffers

\ memory layout:
\   [size:cell] [length:cell] [data...]
\ size == amount of allocated memory units
\ length == amount of in-use memory units
\ data == data stored in the buffer

\ interface:
\
\ buf-new ( size -- buf ):
\ Allocate a new buffer, with the given initial size.  If the size is
\ 0, a default size will be used.
\
\ buf-append ( buf char -- buf ):
\ Append a single byte to the buffer.  The buffer may have to move
\ around, the returned address might not be identical to the passed in
\ address.
\
\ cellbuf-new ( size -- buf ):
\ Like buf-new, but for buffers of cells.
\
\ cellbuf-append ( buf cell -- buf ):
\ Like buf-append, but for buffers of cells.
\
\ buf-count ( buf -- c-addr u ):
\ Convert a buffer to a cell pair string format. Also works for cellbufs.
\
\ strdup ( c-addr1 u -- c-addr2 u ):
\ Create a copy of a cell pair string.  Usable if you want the output
\ of buf-count be usable even after freeing the buffer.
\
\ arrdup ( addr1 u -- addr2 u ):
\ Create a copy of a cell array.  Like strdup but for cellbufs.

: buf-new ( size -- buf )
    dup 0= if drop 16 endif
    dup 2 cells + allocate throw \ size buf
    dup rot swap !               \ buf
    0 over cell+ ! ;

: buf-append ( char buf -- buf )
    dup @ over cell+ @                    \ char buf size len
    = if                                  \ char buf
        dup @ 2* 2 cells + allocate throw \ char buf new-buf
        2dup over @ 2 cells + move
        over @ 2* over !
        swap free throw                   \ char new-buf
    endif                                 \ char buf
    dup dup cell+ @ 2 cells + +           \ char buf new-pos
    rot swap c!                           \ buf
    dup cell+ dup @ 1+ swap ! ;

: buf-count ( buf -- c-addr u )
    cell+ dup cell+ swap @ ;

: cellbuf-new ( size -- buf )
    dup 0= if drop 16 endif
    dup cells 2 cells + allocate throw
    dup rot swap !
    0 over cell+ ! ;

: cellbuf-append ( cell buf -- buf )
    dup @ over cell+ @
    = if
        dup @ cells 2* 2 cells + allocate throw
        2dup over @ cells 2 cells + move
        over @ 2* over !
        swap free throw
    endif
    dup dup cell+ @ cells 2 cells + +
    rot swap !
    dup cell+ dup @ 1+ swap ! ;

: strdup ( c-addr1 u -- c-addr2 u )
    dup allocate throw   \ c-addr1 u c-addr2
    rot over 3 pick move \ u c-addr2
    swap ;

: arrdup ( addr1 u -- addr2 u )
    dup cells allocate throw   \ addr1 u addr2
    rot over 3 pick cells move \ u addr2
    swap ;
