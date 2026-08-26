# Adaptation of ruoso++'s Grammar::EBNF slang code to Grammar::BNF

use Grammar::BNF;

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
my role Slang::BNF {
    rule package-declarator:sym<bnf-grammar> {
        :my $*OUTERPACKAGE := self.package;
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
dd;

#        my $W := $*W;
#        my $longname := $W.dissect_longname($<longname>);
#        my $outer    := $W.cur_lexpad();
#
#        my $name := nqp::getattr(
#          $longname.type_name_parts('package name',:decl(1)),List,'$!reified'
#        );
#        my $target_package := $longname && $longname.is_declared_in_global
#          ?? $*GLOBALish
#          !! $*OUTERPACKAGE;
#        $W.install_package($/,
#          $name, 'our', 'bnf-grammar', $target_package, $outer, $<rules>.made
#        );
#        $/.'make'(QAST::IVal.new(:value(1)));
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
