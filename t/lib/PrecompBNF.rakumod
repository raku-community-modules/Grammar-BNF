use Slang::BNF;

bnf-grammar PrecompG {
<foo> ::= "pre"
};

sub precomp-parses(Str $s) is export { ?PrecompG.parse($s) }
