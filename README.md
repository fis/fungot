fungot, a Funge-98 bot
======================

This is *fungot*, an IRC bot written in Funge-98.

Assorted details related to its operation follow, but there is no "proper" documentation.  For details, your best bet is probably to find `fizzie` on the freenode IRC channel `#esoteric`.

(On the other hand, why are you even interested?)

Features
--------

* Built-in [brainfuck](http://esolangs.org/wiki/Brainfuck) and [Underload](http://esolangs.org/wiki/Underload) interpreters.
* User-defined commands based on the above interpreters.
* Nonsense generation based on [variable-length ngram models](https://github.com/vsiivola/variKN).
* That's about it, really.

Running
-------

Requires: a Funge-98 interpreter with support for the `STRN`, `FILE`, `FING`, `SOCK`, `SCKE`, `REXP`, `TOYS` and `SUBR` fingerprints.  `SCKE` is not actually used, so you may remove the loading of it.  `TOYS` is only used for the `^reload` command.  `SUBR` is used for `^code`.  `REXP` is used for the ignore feature.  The canonical instance on `#esoteric` runs on [cfunge](https://launchpad.net/cfunge/).

To run, you should modify one of the `fungot-load-*.b98` files and then run it.  It will load the `fungot.b98` by itself.  The files should hopefully be more or less self-documenting.  Remember not to misalign any `v`s or `<`s.  Administrative commands such as `^ignore` and `^save` are only accepted if the associated `nick!user@host` prefix matches the one set in the file.

It might be necessary to create the file `data/fungot.dat` and put ten empty lines there.  Available babbling styles are loaded from the file `styles.list`, which should contain lines of the form "label\0description\0" (those are actual 0 bytes) and be terminated with a line containing a single "\0".  The babbling model files are then `model.bin.<label>` and `tokens.bin.<label>`.

Check the standard output of your Funge interpreter for connection details.  Use `^raw JOIN #channel` (as an administrator) in a private message, afterwards.

There might be other details that elude me at the moment.

Commands
--------

The command prefix used here is the default `^`, but you can change that in the configuration file.

Public:

* `^bf <code>[!<input>]`: Run as brainfuck code.  Optional input separated with `!`.
* `^ul <code>`: Run as Underload code.
* `^def <command> <lang> <code>`: Define *command* to run *code* in *lang* (one of `bf` or `ul`).
* `^show [<command>]`: List defined commands, or show source code for one.
* `^str 0-9 get/set/add [<text>]`: Used to define commands longer than the IRC message length.
* `^style [<style>]`: Select babbling model, or show the current/available ones.
* `^bool`: If you have yes/no questions in need for answers.

Administrator-only:

* `^raw <text>`: Send the argument as a raw IRC message.
* `^save`: Save current persistent state (defined commands and `^str` strings).
* `^ignore [<regex>]`: Show or set the ignore regex.  It is matched against the `nick!user@host` prefix.
* `^reload`: Reload the `fungot.b98` file.  Not used very often.  Might break things.
* `^code <text>`: Run the argument as Funge-98 code.  Needs `SUBR`.  Very likely to break things.
