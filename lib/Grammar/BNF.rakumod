my class Actions { ... }

grammar Grammar::BNF {
    token TOP {
        \s* <rule>+ \s*
    }

    # Apparently when used for slang we need a lowercase top rule?
    token main_syntax {
        <TOP>
    }

    token rule {
        <opt-ws> '<' <rule-name> '>' <opt-ws> '::=' <opt-ws> <expression> <line-end>
    }

    token opt-ws {
        \h*
    }

    token rule-name {
        # If we want something other than legal perl 6 identifiers,
        # we would have to implement a FALLBACK.  BNF "specifications"
        # diverge on what is a legal rule name but most expectations are
        # covered by legal Perl 6 identifiers.  Care should be taken to
        # shield from evaluation of metacharacters on a Perl 6 level.
        <.ident>+ % [ <[\-\']> ]
    }

    token expression {
        <list> +% [\s* '|' <opt-ws>]
    }

    token line-end {
        [ <opt-ws> \n ]+
    }

    token list {
        <term> +% <opt-ws>
    }

    token term {
        <literal> | '<' <rule-name> '>'
    }

    token literal {
        '"' <-["]>* '"' | "'" <-[']>* "'"
    }

    # Provide a parse with defaults and also define our per-parse scope.
    method parse(|c) {
        my $*name = c<name> // 'BNFGrammar';
        my %hmod = c.hash;
        %hmod<name>:delete;
        %hmod<actions> = Actions unless %hmod<actions>:exists;
        my \cmod = \(|c.list, |%hmod);
        nextwith(|cmod);
    }

    # We may want to rename this given jnthn's Grammar::Generative
    method generate(|c) {
        my $res = self.parse(|c);
        fail("parse *of* an BNF grammar definition failed.") unless $res;
	return $res.ast;
    }
}

my class Actions {

    my sub guts($/, $rule) {
        use MONKEY-SEE-NO-EVAL;
	# Note: $*name can come from .parse above or from Slang::BNF
        my $grmr := Metamodel::GrammarHOW.new_type(:name($*name));
        my $top = EVAL 'token { <' ~ $rule[0].ast.key ~ '> }';
        $grmr.^add_method('TOP', $top);
        $top.set_name('TOP'); # Makes it appear in .^methods
        for $rule.map(*.ast) -> $rule {
            $rule.value.set_name($rule.key);
            $grmr.^add_method($rule.key, $rule.value);
        }
        $grmr.^compose;
    }

    method TOP($/) {
        make guts($/, $<rule>);
    }

    method main_syntax($/) {
        make guts($/, $<TOP><rule>);
    }

    method rule($/) {
        make $<rule-name>.ast => $<expression>.ast;
    }

    method rule-name($/) {
        make ~$/;
    }

    method expression($/) {
        use MONKEY-SEE-NO-EVAL;
        make EVAL 'token { [ ' ~ $<list>.map(*.ast).join(' | ') ~ ' ] }';
    }

    method list($/) {
        make $<term>.map(*.ast).join(' ');
    }

    method term($/) {
        make ~$/;
    }

    method literal($/) {
        # Prevent evalaution of metachars at Perl 6 level
        make ('[ ', ' ]').join(~$/.ords.fmt('\x%x',' '));
    }
}

# For the slang guts we need an actions class we can find.
class Grammar::BNF-actions is Actions { };

=begin pod

=head1 NAME

Grammar::BNF - Parse (A)BNF grammars and generate Raku grammars from them

=head1 SYNOPSIS

=begin code :lang<raku>

use Grammar::BNF;
my $g = Grammar::BNF.generate(Q:to<END>);
  <foo2> ::= <foo> <foo>
  <foo> ::= "bar"
  END

=end code

=head1 DESCRIPTION

This distribution contains modules for creating Raku Grammar
objects using BNF flavored grammar definition syntax.  Currently
BNF and ABNF are supported.

In addition, the distribution contains Slang modules which allow
use of the grammar definition syntax inline in Raku code.  These
modules may relax their respective syntax slightly to allow for
smoother language integration.

=head1 IDIOMS

This simple example shows how to turn a simple two-line grammar
definition in BNF syntax into a grammar named C<MyGrammar>, and
then uses the resulting grammar to parse the string 'barbar';

=begin code :lang<raku>

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

=end code

Alternatively, you may use a slang to define grammars inline:

=begin code :lang<raku>

use Slang::BNF;
bnf-grammar MyGrammar {
    <foo2> ::= <foo> <foo>
    <foo> ::= "bar"
}; # currently you need this semicolon
MyGrammar.parse('barbar').say; # same as above

=end code

In either case, the first rule appearing in the grammar definition will
be aliased to 'TOP', and will be the default rule applied by C<.parse>.
This is in most respects a true Raku, so subrules may be invoked:

=begin code :lang<raku>

MyGrammar.parse('bar',:rule<foo>).say; # ｢bar｣

=end code

...and the Grammar may be subclassed to add or replace rules with Perl 6
rules:

=begin code :lang<raku>

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

=end code

Currently you have to subclass with a Raku grammar for actions classes
to be provided, but hopefully that limitation will be overcome:

=begin code :lang<raku>

class MyActions { method foo ($match) { "OHAI".say } }
MyOtherGrammar.parse('BarBar', :actions(MyActions)); # says OHAI twice

=end code

=head1 AUTHOR

Tadeusz Sośnierz

=head1 COPYRIGHT AND LICENSE

Copyright 2010 - 2017 Tadeusz Sośnierz

Copyright 2024 Raku Community

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod

# vim: expandtab shiftwidth=4
