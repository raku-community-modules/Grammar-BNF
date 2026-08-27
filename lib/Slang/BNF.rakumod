# Adaptation of ruoso++'s Grammar::EBNF slang code to Grammar::BNF

use Grammar::BNF;
use Slang;

#-------------------------------------------------------------------------------
# Legacy roles
my role Slang::BNF::Legacy {
    rule package_declarator:sym<bnf-grammar> {
        :my $*OUTERPACKAGE := self.package;
        <.sym><.kok>
        :my $*name;
        <longname> { $*name := ~$<longname> }
        '{'
        <rules=.FOREIGN_LANG('Grammar::BNF', 'main_syntax')>
        '}'
        <.set_braid_from(self)>
    }
}
my role Slang::BNF::Actions::Legacy {
    method package_declarator:sym<bnf-grammar>(Mu $/) {
        legacy-install($/, 'bnf-grammar');
    }
}

#-------------------------------------------------------------------------------
# Modern roles

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
        modern-install($/, self);
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
