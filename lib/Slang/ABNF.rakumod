# Adaptation of ruoso++'s Grammar::EBNF slang code to Grammar::ABNF

use Grammar::ABNF;
use Slang;

#-------------------------------------------------------------------------------
# Legacy roles
my role Slang::ABNF::Legacy {
    rule package_declarator:sym<abnf-grammar> {
        :my $*OUTERPACKAGE := self.package;
        <.sym>
        :my $*name;
        :my %*rules;
        :my @*ruleorder;
        :my $*indent;
        <longname> { $*name := ~$<longname> }
        \{
        <rules=.FOREIGN_LANG('Grammar::ABNF::Slang', 'main_syntax')>
        \}
    }
}
my role Slang::ABNF::Actions::Legacy {
    method package_declarator:sym<abnf-grammar>(Mu $/) {
        legacy-install($/, 'abnf-grammar');
    }
}

#-------------------------------------------------------------------------------
# Modern roles

# The RakuAST grammar only consults an added package-declarator candidate
# when the keyword atom comes first in its rule, so the dynamic variable
# declarations come after it.
my role Slang::ABNF {
    rule package-declarator:sym<abnf-grammar> {
        <.sym><.kok>
        :my $*name;
        :my %*rules;
        :my @*ruleorder;
        :my $*indent;
        <longname> { $*name := ~$<longname> }
        \{
        <rules=.FOREIGN-LANG('Grammar::ABNF::Slang', 'main_syntax')>
        \}
        <.set_braid_from(self)>
    }
}
my role Slang::ABNF::Actions {
    method package-declarator:sym<abnf-grammar>(Mu $/) {
        modern-install($/, self);
    }
}

#-------------------------------------------------------------------------------
# The actual slanging
sub EXPORT(|) {
    my $LANG := $*LANG;
    my $raku := $LANG.^name.starts-with('Raku::');

    $LANG.define_slang("MAIN",
      $LANG.slang_grammar('MAIN').^mixin($raku
        ?? Slang::ABNF
        !! Slang::ABNF::Legacy
      ),
      $LANG.slang_actions('MAIN').^mixin($raku
        ?? Slang::ABNF::Actions
        !! Slang::ABNF::Actions::Legacy
      )
    );
    $LANG.define_slang("Grammar::ABNF::Slang",
      Grammar::ABNF::Slang, ABNF-Actions
    );

    BEGIN Map.new
}

# vim: expandtab shiftwidth=4
