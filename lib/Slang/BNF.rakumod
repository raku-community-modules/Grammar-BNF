# Adaptation of ruoso++'s Grammar::EBNF slang code to Grammar::BNF

use Grammar::BNF;
use nqp;
use experimental :rakuast;

# Allow easier access to $<foo> and ~$/ coming from NQP
multi sub postcircumfix:<{ }>(Mu $/, Str:D $key) {
    $/.hash.AT-KEY($key)
}
multi sub prefix:<~>(Mu $/) {
    $/.Str
}

#-------------------------------------------------------------------------------
# Legacy roles
my role Slang::BNF::Legacy {
    rule package_declarator:sym<bnf-grammar> {
        :my $*OUTERPACKAGE := self.package;
        <.sym><.kok>
        :my $*name;
        <longname> { $*name := ~$<longname> }
        \{
        <rules=.FOREIGN_LANG('Grammar::BNF', 'main_syntax')>
        \}
        <.set_braid_from(self)>
    }
}
my role Slang::BNF::Actions::Legacy {
    method package_declarator:sym<bnf-grammar>(Mu $/) {
        use nqp;
        use QAST:from<NQP>;

        # Bits extracted from rakudo/src/Perl6/Grammar.nqp (package_def)
        my $W := $*W;
        my $longname := $W.dissect_longname($<longname>);
        my $outer    := $W.cur_lexpad();

        my $name := nqp::getattr(
          $longname.type_name_parts('package name',:decl(1)),List,'$!reified'
        );
        my $target_package := $longname && $longname.is_declared_in_global
          ?? $*GLOBALish
          !! $*OUTERPACKAGE;
        $W.install_package($/,
          $name, 'our', 'bnf-grammar', $target_package, $outer, $<rules>.made
        );
        $/.'make'(QAST::IVal.new(:value(1)));
    }
}

#-------------------------------------------------------------------------------
# Modern roles

# The declaration is attached as the statement's expression. Overriding
# PERFORM-CHECK keeps the sink check from worrying about a useless use,
# and there is nothing to sink at runtime either.
my class Slang::BNF::Declaration is RakuAST::Term::Declaration {
    method needs-sink-call() { False }
    method PERFORM-CHECK(Mu $resolver, Mu $context) { True }
}

# The RakuAST grammar only consults an added package-declarator candidate
# when the keyword atom comes first in its rule, so the dynamic variable
# declarations come after it.
my role Slang::BNF {
    rule package-declarator:sym<bnf-grammar> {
        <.sym><.kok>
        :my $*name;
        <longname> { $*name := ~$<longname> }
        \{
        <rules=.FOREIGN-LANG('Grammar::BNF', 'main_syntax')>
        \}
        <.set_braid_from(self)>
    }
}
my role Slang::BNF::Actions {
    method package-declarator:sym<bnf-grammar>(Mu $/) {
        my $grammar := $<rules>.made;
        my @parts = (~$<longname>).split('::');
        my $final = @parts.pop;
        my $single = !@parts;

        # A leading GLOBAL part addresses the top level package no matter
        # where the declaration appears. Everything else binds relative to
        # the enclosing package, like an "our"-scoped declaration.
        my Mu $target;
        if @parts && @parts[0] eq 'GLOBAL' {
            @parts.shift;
            $target := $*R.get-global;
        }
        else {
            $target := $*R.current-package;
        }

        # Bind the remaining name parts, creating stub packages for the
        # intermediate ones. A stub created for the first part also gets
        # a lexical so the name resolves inside the enclosing package.
        my $prefix = '';
        my $depth = 0;
        for @parts -> $part {
            $prefix = $prefix ?? $prefix ~ '::' ~ $part !! $part;
            my Mu $stash := $target.WHO;
            if $stash.EXISTS-KEY($part) {
                $target := $stash.AT-KEY($part);
            }
            else {
                my Mu $stub := Metamodel::PackageHOW.new_type(:name($prefix));
                $stash.BIND-KEY($part, $stub);
                if $depth == 0 {
                    $*R.current-scope.merge-generated-lexical-declaration:
                        RakuAST::Declaration::Import.new(
                            :lexical-name($part), :compile-time-value($stub)
                        ),
                        :resolver($*R), :force;
                }
                $target := $stub;
            }
            $depth++;
        }

        # When a stub package of the same name already exists, the grammar
        # adopts its stash so grammars bound under the stub stay reachable.
        my Mu $stash := $target.WHO;
        if $stash.EXISTS-KEY($final)
          && $stash.AT-KEY($final).HOW.WHAT =:= Metamodel::PackageHOW {
            nqp::setwho($grammar, nqp::decont($stash.AT-KEY($final).WHO));
        }
        $stash.BIND-KEY($final, $grammar);

        # Single-part names also get a lexical so they resolve directly.
        if $single {
            $*R.current-scope.merge-generated-lexical-declaration:
                RakuAST::Declaration::Import.new(
                    :lexical-name($final), :compile-time-value($grammar)
                ),
                :resolver($*R), :force;
        }

        self.attach: $/, Slang::BNF::Declaration.new(
            RakuAST::Declaration::ResolvedConstant.new(
                :compile-time-value($grammar)
            )
        );
    }
}

#-------------------------------------------------------------------------------
# The actual slanging
my sub EXPORT(|) {
    my $LANG := $*LANG;
    my $raku := $LANG.^name.starts-with('Raku::');

    $LANG.define_slang("MAIN",
      $LANG.slang_grammar('MAIN').^mixin($raku
        ?? Slang::BNF
        !! Slang::BNF::Legacy
      ),
      $LANG.slang_actions('MAIN').^mixin($raku
        ?? Slang::BNF::Actions
        !! Slang::BNF::Actions::Legacy
      )
    );
    $LANG.define_slang("Grammar::BNF", Grammar::BNF, Grammar::BNF-actions);

    BEGIN Map.new
}

# vim: expandtab shiftwidth=4
