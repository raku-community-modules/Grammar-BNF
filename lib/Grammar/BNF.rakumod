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
        # If we want something other than legal Raku identifiers,
        # we would have to implement a FALLBACK.  BNF "specifications"
        # diverge on what is a legal rule name but most expectations are
        # covered by legal Raku identifiers.  Care should be taken to
        # shield from evaluation of metacharacters on a Raku level.
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
        # Prevent evaluation of metachars at Raku level
        make ('[ ', ' ]').join(~$/.ords.fmt('\x%x',' '));
    }
}

# For the slang guts we need an actions class we can find.
class Grammar::BNF-actions is Actions { };

# vim: expandtab shiftwidth=4
