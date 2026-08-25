class ABNF-Actions {...}

grammar Grammar::ABNF::Core {
    # RFC 5234 Appendix B.1. "Core Rules"
    token ALPHA       { <[\x41..\x5a] + [\x61..\x7a]> }
    token BIT         { <[\x30 \x31]> }
    token CHAR        { <[\x01..\x7f]> }
    token CR          { \x0d }
    token CRLF        { \x0d \x0a }
    token CTL         { <[\x00..\x1f] + [\x7f]> }
    token DIGIT       { <[\x30..\x39]> }
    token DQUOTE      { \x22 }
    token HEXDIG      { <+ DIGIT + [\x41..\x46] + [\x61..\x66]> }
    token HTAB        { \x09 }
    token LWSP        { [ <.WSP> | <.CRLF> <.WSP> ]* }
    token LF          { \x0a }
    token OCTET       { <[\x00..\xff]> }
    token SP          { \x20 }
    token VCHAR       { <[\x21..\x7e]> }
    token WSP         { <+SP + HTAB> }
}

grammar Grammar::ABNF is Grammar::ABNF::Core {

    token TOP {
# TODO deal with indentation and folded rules
#        \s*? (<!after " ">\s*)
#        { $*indent = $/[0].chars; }
        <rulelist> \s*
    }

    token main_syntax { <TOP> }

    # Rule names are directly from RFC 5234 Section 4 for this section
    token rulelist {
#        [ <rule> | [ <.c-wsp>* <.c-nl> ] ]+
# RFC 5234 errata ID 3076
        [ <rule> | [ <.WSP>* <.c-nl> ] ]+
    }

    # Altered for indenting behavior
    regex rule {
        # New rules can start if they are not indented more than the last rule
#        ( <.WSP>**{0..$*indent} )
        <rulename> <defined-as> <elements> <.c-nl>
        # ratchet in the indent
#        { $*indent = $0.chars }
    }

    # This is not in the RFC but helps keep things DRY
    token name {
        :i (<+alpha><+alnum +[-]>+)
    }

    token rulename {
        [ '<' <name> '>' ] | <name>
    }

    token defined-as {
        <.c-wsp>* ("=" | "=/") <.c-wsp>*
    }

    token elements {
#        <alternation> <.c-wsp>*
# RFC 5234 errata ID 2968
        <alternation> <.WSP>*
    }

    # We just do this the way the RFC does, though unnecessary
    regex c-wsp {
        <.WSP> | [ <.c-nl> <.WSP> ]
    }

    regex c-nl {
        [ <.comment> | <.CRLF> ]
    }

    token comment {
        ';' ( <+WSP +VCHAR> )* <.CRLF>
    }

    regex alternation {
        <concatenation>+ % [ <.c-wsp>* "/" <.c-wsp>* ]
    }

    regex concatenation {
        <repetition>+ % <.c-wsp>+
    }

    regex repetition {
        <repeat>? <element>
    }

    token repeat {
        [$<min>=[<.DIGIT>+]]? [$<star>='*']? [$<max>=[<.DIGIT>+]]? {
            X::Syntax::Regex::MalformedRange.new.throw
                if ($/<min> // 0) > ($/<max> // Inf);
        }
    }

    token element {
        <rulename> || <group> | <option> | <char-val> | <num-val> | <prose-val>
    }

    token group {
        "(" <.c-wsp>* <alternation> <.c-wsp>* ")"
    }

    token option {
        "[" <.c-wsp>* <alternation> <.c-wsp>* "]"
    }

    token char-val {
        <.DQUOTE> (<[\x20..\x21] + [\x23..\x7E]>*) <.DQUOTE>
    }

    token num-val {
        "%" [ <bin-val> | <dec-val> | <hex-val> ]
    }

    token bin-val { "b" [ [ $<val>=[<.BIT>+] ]+ % "." |
                            $<min>=[<.BIT>+] "-" $<max>=[<.BIT>+] ]
                  }

    token dec-val { "d" [ [ $<val>=[<.DIGIT>+] ]+ % "." |
                            $<min>=[<.DIGIT>+] "-" $<max>=[<.DIGIT>+] ]
                  }

    token hex-val { "x" [ [ $<val>=[<.HEXDIG>+] ]+ % "." |
                            $<min>=[<.HEXDIG>+] "-" $<max>=[<.HEXDIG>+] ]
                  }

    token prose-val {
        "<" (<[\x20..\x3D] + [\x3F..\x7E]>*) ">"
    }

    # This method also sets up some internal state, so subgrammars
    # should be careful to properly wrap it when providing their
    # own C<.parse> method.
    method parse(|c) {
        my %*rules;
        my @*ruleorder;
        my $*indent;
        my $*name = c<name> // 'ABNF-Grammar';
        my %hmod = c.hash;
        %hmod<name>:delete;
        %hmod<actions> = ABNF-Actions unless %hmod<actions>:exists;
        my \cmod = \(|c.list, |%hmod);
        nextwith(|cmod);
    }

    # This method will also be added to grammars created from
    # ABNF descriptions.  In that case, user-defined rule names
    # will present as lowercase under introspection.
    #
    # In order to allow ABNF rules that are not legal Raku
    # identifiers, hypens and underscores will also be folded.
    method FALLBACK (Grammar: Str $name, |c) {
        # Break fallback loops
        if $name eq "name" {
            return self.^name;
        }

        # $name has to be sanitized a bit, but we cannot use <name>
        # from above as it may recurse if it has been overridden.
        my $cname = ~$name.lc;
        $cname ~~ tr/\-/_/;
        my $m = self.^methods.map(*.name).grep(
            {
                my $rname = $_.lc;
                $rname ~~ tr/\-/_/;
                $rname eq $cname
            })[0];
        die X::Method::NotFound.new(
            :method($name) :typename(self.^name) :!private
        ) unless $m;
        # TODO: and self.^find_method($name) ~~ Regex; # or something
        self."$m"(|c);
    }

    # We may want to rename this given jnthn's Grammar::Generative
    method generate(|c) {
        my $res = self.parse(|c);
        fail("parse *of* an ABNF grammar definition failed.") unless $res;
        return $res.made;
    }
}

class ABNF-Actions {

    my sub guts($/) {
        use MONKEY-SEE-NO-EVAL;
        # Note: $*name can come from .parse above or from Slang::BNF
        my $grmr := Metamodel::GrammarHOW.new_type(:name($*name));
        my $top = EVAL 'token { <' ~ @*ruleorder[0] ~ '> }';
        $top.set_name('TOP'); # There are two name slots IIRC.
        $grmr.^add_method('TOP', $top);
        for %*rules.pairs -> $rule {
            my $r = EVAL 'token { ' ~ $rule.value ~ ' }';
            $r.set_name($rule.key);
            $grmr.^add_method($rule.key, $r);
        }
        $grmr.^add_method("FALLBACK", Grammar::ABNF.^find_method('FALLBACK'));
        $grmr.^compose;
        make $grmr;
    }

    method TOP($/) {
        make guts($/);
    }

    method main_syntax($/) {
        make guts($/);
    }

    method rule($/) {
        my $rulename = $/<rulename>.made;
        my $ruleval = $/<elements><alternation>.made;
        if (%*rules{$rulename}:exists) {
            if $/<defined-as> eq '=' {
                X.Redeclaration.new(:symbol($rulename)
                                    :what('Regex')
                                    :postfix('in ABNF definitions')).throw;
            }
            %*rules{$rulename} ~= " | $ruleval";
        }
        else {
            push @*ruleorder, $rulename;
            %*rules{$rulename} = "$ruleval";
        }
    }

    method rulename($/) {
        my $n = ~$/<name>;
        $n = $n.lc;
        # Try to paper over the fact that perl6 rulenames cannot contain
        # a hyphen followed by a decimal or at the end.
        $n = $n.split(/ \- <.before [ \d | $ ]> /).join("_");
        make $n;
    }

    method alternation($/) {
        make join(" | ", $/<concatenation>[]».made)
    }

    method concatenation($/) {
        make join(" ", $/<repetition>[]».made)
    }

    method repetition($/) {
        make $/<element>.made unless $/<repeat>.defined;
        my $repeat = '';
        if $/<repeat><star> {
            my $min = $/<repeat><min> // 0;
            my $max = $/<repeat><max> // '*';
            $repeat = '**' ~ $min ~ ".." ~ $max;
        }
        elsif $/<repeat><min> {
            $repeat ~= '**' ~ $/<repeat><min>;
        }
        make "[[ " ~ $/<element>.made ~ " ]" ~ "$repeat ]";
    }

    method element($/) {
        # Only one of these will exist
        if $/<rulename> {
            # Try to paper over the fact that perl6 rulenames cannot contain
            # a hyphen followed by a decimal or at the end.
            my $rn =
                ~$/<rulename>.made.split(/\-<.before [ \d | $ ]>/).join("_");
            make "<$rn>";
        }
        else {
            make $/<group option char-val
                    num-val prose-val>.first(*.defined).made;
        }
    }

    method group($/) {
        make "[ " ~ $/<alternation>.made ~ " ]";
    }

    method option($/) {
        make "[ " ~ $/<alternation>.made ~ " ]?";
    }

    method char-val($/) {
        # Don't EVAL metachars.  I do not curently trust /$foo/ as it still
        # needs work IIRC.  Later we should be able to do something like:
        #
        # my $f = $/[0]; make rx:ratchet/$f/;
        #
        # So here is the brute force interim solution.
        #
        # The .ords may get deprecated with NFG, and synthetic-leak-refusal
        # would cause trouble here.  Really we need to use the encoding
        # of the source and re-encode it.  But it will be 8-bit for most uses,
        # so deal with it later.
        make "[ " ~
             (~$/[0].comb.map({ "<[" ~
                                ($_.uc,$_.lc).map({$_.ords}).fmt('\x%x', ' ')
                                ~ "]>"
                              }).join)
              ~ " ]";
    }

    method num-val($/) {
        # Only one of these will exist
        make $/<bin-val dec-val hex-val>.first(*.defined).made;
    }

    # For all the num-vals, the RFC does not put limits on the number of
    # digits nor the codepoint values (You can use ABNF on unicode if you
    # really want to, if you adjust the "core rules" in B.1.)  We could
    # just shove the strings back into the Raku regexps, but instead we
    # write it in a way that is convenient to customize/sanitize.
    my sub numval ($m, &rad2num) {
        if $m<val> {
            join(" ", "[", $m<val>[].map({ rad2num(~$_).fmt('\\x%x') }), "]")
        }
        else {
            sprintf('<[\\x%x..\\x%x]>', $m<min max>.map: { rad2num(~$_) })
        }
    }

    method bin-val($/) {
        make numval($/, { :2($^n) });
    }

    method dec-val($/) {
        make numval($/, { :10($^n) });
    }

    method hex-val($/) {
        make numval($/, { :16($^n) });
    }

    method prose-val($/) {
        make qq:to<EOCODE>;
        \{X::NYI.new(:feature(｢$/[0]｣.fmt(Q:to<ERR>) ~ 'Such a mixin')).throw\}
            This ABNF Grammar requires you to mix in custom code to do
            the following:
                %s
            ...which you may have to write yourself.
            ERR
        EOCODE
    }
}

# Makes the slang version awesome by softening CRLF to match surrounding code
# Maybe allow mixing in Raku-style comments in the future
grammar Grammar::ABNF::Slang is Grammar::ABNF {
    rule CRLF { \n | $ }
}

# vim: expandtab shiftwidth=4
