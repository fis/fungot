How to use this thing
---------------------

0. Prerequisites

Fetch the varikn-1.0.2 toolkit from:
  http://forge.pascal-network.org/frs/shownotes.php?release_id=30

Unpack it in the "varikn-1.0.2" subdirectory and compile.

1. Find some data.

What you need is is some data in the format where there is a single "phrase"
(whatever you want that to mean) on one line, and no other cruft. Personally I
tend to use horrible shell pipelines combining tr, awk, sed, perl and whatnot
to do this. In the end you should have your data in "foo_data.txt".

2. Preprocessing.

Convert the punctuation in the data to tokens with:

  ./preprocess.pl < foo_data.txt > foo_tokens.txt

This will result in a similarly formatted file "foo_tokens.txt", except most of
the punctuation has been replaced with "PFOO" tokens, and each individual token
is space-separated.  There is still one line per "phrase".

Avoid looking at the preprocess.pl code. It evolved from IRC log processing
scripts, and is not pretty (or well-working). If you want, you can do this
tokenizing yourself too.

3. Split the data to training and held-out set.

There are official rules for the sizes of the sets in the varikn documentation,
but generally I don't have enough data to be very picky. Here is an example for
a really tiny dataset. Using something much smaller probably won't work very
well. This step also adds the sentence start and end tokens expected by the
varikn code.

  wc -l foo_tokens.txt
  => 2638 foo_tokens.txt
  head -n 2200 foo_tokens.txt | sed -e 's#.*#<s> & </s>#' > foo_train.txt
  tail -n 438 foo_tokens.txt | sed -e 's#.*#<s> & </s>#' > foo_heldout.txt

Now you have "foo_train.txt" and "foo_heldout.txt" for model training.

4. Grow the language model.

Do it like this:

  varikn-1.0.2/varigram_kn \
    -o foo_heldout.txt -D 0.005 -E 0.02 -C -3 foo_train.txt -a foo.arpa

The D and E arguments control the generated model size. You will probably have
to do some tweaking based on your input data. There are guidelines also in the
varikn documentation, but they might not be expecting this sort of use.

This step will write the n-gram model in the sort-of-standard ARPA tool format
into the "foo.arpa" file.

5. Convert to fungot's language model format.

Do this:

  ./arpa2fungot.pl foo.arpa tokens.bin.foo model.bin.foo

This will read in the "foo.arpa" model, and write the binary data files
"tokens.bin.foo" and "model.bin.foo". For format specification, see Appendix A
of this document.

6. Test the language model. (Optional.)

For very small models, you can use the fast in-memory version:

  ./testlm.pl tokens.bin.foo model.bin.foo [N] [prefix ...]

For larger models (the Perl in-memory representation is huge, a 200 megabyte
model will not fit into 3 gigabytes of RAM, and will take ages to load) use the
on-disk variant, "testlm-disk.pl", which has identical command line arguments.
Beware, though, that even the disk version reads the whole token data to
memory. This is rather ugly, but hey: the test utility for the ad-hoc language
model construction actually *constructed* the language model before generating
babble.

The two model file arguments are required. The optional N argument is an
integer; that many output phrases will be generated. By default a single line
of output is generated. After the count, you can give some words: the generated
output will start with these words, and they will be used as the initial
context. If the word you give is not in the list of tokens, a warning will be
printed and the "unknown" token substituted. You will have to explicitly give
the PFOO tokens if you want punctuation.

7. Install your new model in fungot.

I have to eat some food now, I'll document this, Appendix A, and the other
stuff later. Sorry. I hope no-one sees this.
