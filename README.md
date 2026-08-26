[![Actions Status](https://github.com/raku-community-modules/Grammar-BNF/actions/workflows/linux.yml/badge.svg)](https://github.com/raku-community-modules/Grammar-BNF/actions) [![Actions Status](https://github.com/raku-community-modules/Grammar-BNF/actions/workflows/macos.yml/badge.svg)](https://github.com/raku-community-modules/Grammar-BNF/actions) [![Actions Status](https://github.com/raku-community-modules/Grammar-BNF/actions/workflows/windows.yml/badge.svg)](https://github.com/raku-community-modules/Grammar-BNF/actions)

NAME
====

Grammar::(A)BNF - Parse (A)BNF grammars and generate Raku grammars from them

SYNOPSIS
========

```raku
use Grammar::BNF;
my $g = Grammar::BNF.generate(Q:to<END>);
  <foo2> ::= <foo> <foo>
  <foo> ::= "bar"
  END

use Grammar::ABNF;
my $g = Grammar::ABNF.parse(qq:to<END>, :name<MyGrammar>).made;
  macaddr  = 5( octet [ ":" / "-" ] ) octet\r
  octet    = 2HEXDIGIT\r
  HEXDIGIT = %x30-39 / %x41-46 / %x61-66\r
  END

$g.parse('02-BF-C0-00-02-01')<macaddr><octet>».Str.print; # 02BFC0000201
```

DESCRIPTION
===========

This distribution contains modules for creating Raku Grammar objects using BNF flavored grammar definition syntax. Currently BNF and ABNF are supported.

In addition, the distribution contains Slang modules which allow use of the grammar definition syntax inline in Raku code. These modules may relax their respective syntax slightly to allow for smoother language integration.

BNF
===

This simple example shows how to turn a simple two-line grammar definition in BNF syntax into a grammar named `MyGrammar`, and then uses the resulting grammar to parse the string 'barbar';

```raku
use Grammar::BNF;
my $g = Grammar::BNF.generate(Q:to<END>);
  <foo2> ::= <foo> <foo>
  <foo> ::= "bar"
  END

$g.parse('barbar').say;
# ｢barbar｣
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

...and the Grammar may be subclassed to add or replace rules with Raku rules:

```raku
grammar MyOtherGrammar is MyGrammar {
    token foo { B <ar> }
    token ar  { ar }
}
MyOtherGrammar.parse('BarBar').say;
# ｢BarBar｣
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

ABNF::Core
==========

The ABNF grammar contains the core ABNF ruleset as defined in RFC 5234 Appendix B.1. The rule names are uppercase as they appear in the RFC and must be used as such; this grammar does not perform case folding.

ABNF
====

This grammar contains the full ABNF ruleset as defined in RFC 5234. The extra rules `TOP`, `main_syntax` and `name` are present and used for internal purposes.

Note that the `CRLF` rule is strictly conformant. If you want to accept alternative newlines, you must override it by defining a subclass.

Currently this module does not handle multi-line rules nor even any whitespace prior to the rule on a line. For now, use heredocs to de-indent.

A custom `.parse` method is provided. By default, this method will pull in a `:actions` class which will create a Raku Grammar in the `.made` attribute attached to any successful `Match`. In addition, a type name for the created Raku Grammar may be provided with `:name`. This defaults to `'ABNF-Grammar'`. It is advised that you provide your own.

This method also sets up some internal state, so subgrammars should be careful to properly wrap it when providing their own `.parse` method.

ABNF rules may be used in a case-insensitive fashion, though in Grammar::ABNF itself, they will present themselves with the casing they have in the RFC under introspection. A `FALLBACK` method is provided which performs case folding where it cannot be part of the rules themselves.

This method will also be added to grammars created from ABNF descriptions. In that case, user-defined rule names will present as lowercase under introspection.

In order to allow ABNF rules that are not legal Raku identifiers, hypens and underscores will also be folded.

REFERENCES
==========

  * "RFC 5234: Augmented BNF for Syntax Specifications: ABNF" (Crocker,Overall,THUS) [https://tools.ietf.org/html/rfc5234](https://tools.ietf.org/html/rfc5234)

AUTHOR
======

Tadeusz Sośnierz

COPYRIGHT AND LICENSE
=====================

Copyright 2010 - 2017 Tadeusz Sośnierz

Copyright 2024, 2026 Raku Community

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

