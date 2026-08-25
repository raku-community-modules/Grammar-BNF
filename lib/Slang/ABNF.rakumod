# Adaptation of ruoso++'s Grammar::EBNF slang code to Grammar::ABNF

use Grammar::ABNF;

# Allow easier access to $<foo> and ~$/ coming from NQP
multi sub postcircumfix:<{ }>(Mu $/, Str:D $key) {
    $/.hash.AT-KEY($key)
}
multi sub prefix:<~>(Mu $/) {
    $/.Str
}

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
        use nqp;
        use QAST:from<NQP>;

        # Bits extracted from rakudo/src/Perl6/Grammar.nqp (package_def)
        my $W := $*W;
        my $longname := $W.dissect_longname($<longname>);
        my $outer    := $W.cur_lexpad;

        my $name := nqp::getattr(
          $longname.type_name_parts('package name',:decl(1)),List,'$!reified'
        );
        my $target_package := $longname && $longname.is_declared_in_global
          ?? $*GLOBALish
          !! $*OUTERPACKAGE;
        $W.install_package($/,
          $name, 'our', 'abnf-grammar', $target_package, $outer, $<rules>.made
        );
        $/.'make'(QAST::IVal.new(:value(1)));

    }
}

sub EXPORT(|) {
    my $LANG := $*LANG;

    $LANG.define_slang("MAIN",
      $LANG.slang_grammar('MAIN').^mixin(Slang::ABNF::Legacy),
      $LANG.slang_actions('MAIN').^mixin(Slang::ABNF::Actions::Legacy)
    );
    $LANG.define_slang("Grammar::ABNF::Slang",
      Grammar::ABNF::Slang, ABNF-Actions
    );

    BEGIN Map.new
}

# vim: expandtab shiftwidth=4
