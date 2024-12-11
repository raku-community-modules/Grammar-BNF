# Adaptation of ruoso++'s Grammar::EBNF slang code to Grammar::BNF

use Grammar::BNF;
use nqp;
use QAST:from<NQP>;
sub EXPORT(|) {
    my sub lk(Mu \h, \k) {
        nqp::atkey(nqp::findmethod(h, 'hash')(h), k)
    }
    role Slang::BNF {
        rule package_declarator:sym<bnf-grammar> {
            :my $*OUTERPACKAGE := self.package;
            <sym>
            :my $*name;
            <longname> { $*name := lk($/,'longname').Str }
            \{
            <rules=.FOREIGN_LANG('Grammar::BNF', 'main_syntax')>
            \}
            <.set_braid_from(self)>
        }
    }
    role Slang::BNF::Actions {
        method package_declarator:sym<bnf-grammar>(Mu $/) {
            # Bits extracted from rakudo/src/Perl6/Grammar.nqp (package_def)
            my $longname := $*W.dissect_longname(lk($/,'longname'));
            my $outer := $*W.cur_lexpad();
            # Locate any existing symbol. Note that it's only a match
            # with "my" if we already have a declaration in this scope.
            my $exists := 0;
            my $name := nqp::getattr($longname.type_name_parts('package name', :decl(1)), List, '$!reified');
            my $target_package :=
                $longname && $longname.is_declared_in_global()
                ?? $*GLOBALish
                !! $*OUTERPACKAGE;
            my $*PACKAGE = lk($/,"rules").made();
            $*W.install_package($/, $name, 'our', 'bnf-grammar',
                                $target_package, $outer, $*PACKAGE);
            $/.'make'(QAST::IVal.new(:value(1)));
        }
    }

    my Mu $MAIN-grammar := nqp::atkey(%*LANG, 'MAIN');
    my $grammar := $MAIN-grammar.^mixin(Slang::BNF);
    my Mu $MAIN-actions := nqp::atkey(%*LANG, 'MAIN-actions');
    my $actions := $MAIN-actions.^mixin(Slang::BNF::Actions);

    # old way
    try {
        nqp::bindkey(%*LANG, 'MAIN', $grammar);
        nqp::bindkey(%*LANG, 'MAIN-actions', $actions);
        nqp::bindkey(%*LANG, 'Grammar::BNF', Grammar::BNF);
        nqp::bindkey(%*LANG, 'Grammar::BNF-actions', Grammar::BNF-actions);
    }
    # new way
    try {
        $*LANG.define_slang("MAIN", $grammar, $actions);
        $*LANG.define_slang("Grammar::BNF", Grammar::BNF, Grammar::BNF-actions);
    }
    {}
}

# vim: expandtab shiftwidth=4
