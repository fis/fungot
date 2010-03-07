\ (unbalanced) tree-based string-keyed maps

\ interface:
\
\ map-set ( value key-addr key-u map1 -- map2 )
\ Add a new or change existing entry in the map.  A private copy of
\ the key string will be made, if a new entry is added.  The returned
\ map will be same as the one that was passed in, except in case you
\ pass in a 0.
\
\ map-find ( key-addr key-u map -- map )
\ Find a node with the given key.
\
\ map-get ( key-addr key-u map -- ?value not-found? )
\ Find a value corresponding to key.  not-found? will be true if the
\ value was not found; in this case ?value will not be on stack.
\
\ map-iterate ( xt map -- )
\ Execute xt for each map entry, ordered by key.  xt's stack effect
\ must be ( value key-addr key-u -- ).

require buf.fs

struct
    double% field map-key
    cell% field map-data
    cell% field map-left
    cell% field map-right
end-struct map%

: map-set ( value key-addr key-u map1 -- map2 )
    dup { map }
    0= if
        map% %alloc to map
        strdup map map-key 2! map map-data !
        0 map map-left ! 0 map map-right !
        map exit
    endif
    2dup map map-key 2@ compare case
        -1 of map map-left @ recurse map map-left ! map exit endof
        1 of map map-right @ recurse map map-right ! map exit endof
    endcase
    2drop map map-data ! map ;

: map-find ( key-addr key-u map -- map )
    dup { map }
    0= if 0 exit endif
    2dup map map-key 2@ compare case
        -1 of map map-left @ recurse exit endof
        1 of map map-right @ recurse exit endof
    endcase
    2drop map ;

: map-get ( key-addr key-u map -- ?value not-found? )
    map-find
    ?dup-0=-if true exit endif
    map-data @ false ;

: map-iterate ( xt map -- )
    dup map-left @ ?dup-if 2 pick swap recurse endif
    dup map-data @ over map-key 2@ 4 pick execute
    map-right @ ?dup-if recurse else drop endif ;
