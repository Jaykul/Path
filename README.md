# Path

The Path module containts nothing but a `[Path()]` attribute for command parameters, and some tests to prove that it works.

Imagine if Windows PowerShell could resolve paths for you, so that without writing extra code, you could guarantee that user input to a `$Path` parameter was a fully qualified path.

It can. Just add this module as a dependency and use `[Path()]` on your `$Path` parameter.

## Of course, really, it should do more than that.

1. It should work with `$LiteralPath` parameters too!
2. It should be able to ensure the path points at an existing file...
3. Or to ensure the path points at an existing folder...
4. Or to ensure the path doesn't point at an existing item!
5. It should probably produce better error messages

There's probably more, but I haven't thought of all the things it should do.

Want to help? Please, help me by writing some feature specs or tests. 