# Common logic for Grammar::(A)BNF slangs
use nqp;
use experimental :rakuast;

# Allow easier access to $<foo> and ~$/ coming from NQP
multi sub postcircumfix:<{ }>(Mu $/, Str:D $key) is export {
    $/.hash.AT-KEY($key)
}
multi sub prefix:<~>(Mu $/) is export {
    $/.Str
}

#-------------------------------------------------------------------------------
# Legacy install
my sub legacy-install(Mu $/, str $token) is export {
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
      $name, 'our', $token, $target_package, $outer, $<rules>.made
    );
    $/.'make'(QAST::IVal.new(:value(1)));
}

#-------------------------------------------------------------------------------
# Modern install

# The declaration is attached as the statement's expression. Overriding
# PERFORM-CHECK keeps the sink check from worrying about a useless use,
# and there is nothing to sink at runtime either.
my class Slang::Declaration is RakuAST::Term::Declaration {
    method needs-sink-call(--> False) { }
    method PERFORM-CHECK(Mu $resolver, Mu $context --> True) { }
}

my sub modern-install(Mu $/, Mu $attachee) is export {
    my $resolver := $*R;
    my $grammar  := $<rules>.made;
    my str @parts = (~$<longname>).split('::');
    my str $final = @parts.pop;

    # A leading GLOBAL part addresses the top level package no matter
    # where the declaration appears. Everything else binds relative to
    # the enclosing package, like an "our"-scoped declaration.
    my Mu $target := do if @parts && @parts[0] eq 'GLOBAL' {
        @parts.shift;
        $resolver.get-global
    }
    else {
        $resolver.current-package
    }

    # Bind the remaining name parts, creating stub packages for the
    # intermediate ones. A stub created for the first part also gets
    # a lexical so the name resolves inside the enclosing package.
    my str $prefix;
    for @parts -> str $part {
        $prefix = $prefix ?? $prefix ~ '::' ~ $part !! $part;
        my Mu $stash := $target.WHO;
        $target := do if $stash.EXISTS-KEY($part) {
            $stash.AT-KEY($part)
        }
        else {
            my Mu $stub := Metamodel::PackageHOW.new_type(:name($prefix));
            $stash.BIND-KEY($part, $stub);

            # First parts gets its own lexical
            $resolver.current-scope.merge-generated-lexical-declaration(
              RakuAST::Declaration::Import.new(
                :lexical-name($part), :compile-time-value($stub)
              ),
              :$resolver, :force
            ) if $part eq $prefix;
            $stub
        }
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
    unless @parts {
        $resolver.current-scope
          .merge-generated-lexical-declaration(
            RakuAST::Declaration::Import.new(
                :lexical-name($final), :compile-time-value($grammar)
            ),
            :$resolver, :force
          );
    }

    $attachee.attach: $/, Slang::Declaration.new(
      RakuAST::Declaration::ResolvedConstant.new(
        :compile-time-value($grammar)
      )
    );
}

# vim: expandtab shiftwidth=4
