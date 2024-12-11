[![Actions Status](https://github.com/raku-community-modules/Grammar-BNF/actions/workflows/linux.yml/badge.svg)](https://github.com/raku-community-modules/Grammar-BNF/actions) [![Actions Status](https://github.com/raku-community-modules/Grammar-BNF/actions/workflows/macos.yml/badge.svg)](https://github.com/raku-community-modules/Grammar-BNF/actions) [![Actions Status](https://github.com/raku-community-modules/Grammar-BNF/actions/workflows/windows.yml/badge.svg)](https://github.com/raku-community-modules/Grammar-BNF/actions)

NAME
====

Grammar::BNF - Parse (A)BNF grammars and generate Raku grammars from them

SYNOPSIS
========

```raku
use Grammar::BNF;
my $g = Grammar::BNF.generate(Q:to<END>);
  <foo2> ::= <foo> <foo>
  <foo> ::= "bar"
  END
```

DESCRIPTION
===========

This distribution contains modules for creating Raku Grammar objects using BNF flavored grammar definition syntax. Currently BNF and ABNF are supported.

In addition, the distribution contains Slang modules which allow use of the grammar definition syntax inline in Raku code. These modules may relax their respective syntax slightly to allow for smoother language integration.

IDIOMS
======

This simple example shows how to turn a simple two-line grammar definition in BNF syntax into a grammar named `MyGrammar`, and then uses the resulting grammar to parse the string 'barbar';

```raku
use Grammar::BNF;
my $g = Grammar::BNF.generate(Q:to<END>);
  <foo2> ::= <foo> <foo>
  <foo> ::= "bar"
  END
                              );
$g.parse('barbar').say; # ｢barbar｣
                        #  foo2 => ｢barbar｣
                        #   foo => ｢bar｣
                        #   foo => ｢bar｣
```

Alternatively, you may use a slang to define grammars inline:

```raku
use Slang::BNF;
bnf-grammar MyGrammar {
    <foo2> ::= <foo> <foo>
    <foo> ::= "bar"
}; # currently you need this semicolon
MyGrammar.parse('barbar').say; # same as above
```

In either case, the first rule appearing in the grammar definition will be aliased to 'TOP', and will be the default rule applied by `.parse`. This is in most respects a true Raku, so subrules may be invoked:

```raku
MyGrammar.parse('bar',:rule<foo>).say; # ｢bar｣
```

...and the Grammar may be subclassed to add or replace rules with Perl 6 rules:

```raku
grammar MyOtherGrammar is MyGrammar {
    token foo { B <ar> }
    token ar  { ar }
}
MyOtherGrammar.parse('BarBar').say; # ｢BarBar｣
                                    #  foo2 => ｢BarBar｣
                                    #   foo => ｢Bar｣
                                    #    ar => ｢ar｣
                                    #   foo => ｢Bar｣
                                    #    ar => ｢ar｣
```

Currently you have to subclass with a Raku grammar for actions classes to be provided, but hopefully that limitation will be overcome:

```raku
class MyActions { method foo ($match) { "OHAI".say } }
MyOtherGrammar.parse('BarBar', :actions(MyActions)); # says OHAI twice
```

AUTHOR
======

Tadeusz Sośnierz

COPYRIGHT AND LICENSE
=====================

Copyright 2010 - 2017 Tadeusz Sośnierz

Copyright 2024 Raku Community

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

