package Data::Sah::Compiler::human::TH::array;

use 5.010;
use Log::Any '$log';
use Moo;
extends 'Data::Sah::Compiler::human::TH';
with 'Data::Sah::Compiler::human::TH::Comparable';
with 'Data::Sah::Compiler::human::TH::HasElems';
with 'Data::Sah::Type::array';

# VERSION

sub handle_type {
    my ($self, $cd) = @_;
    my $c = $self->compiler;

    $c->add_ccl($cd, {
        fmt   => ["array", "arrays"],
        type  => 'noun',
    });
}

sub clause_each_elem {
    my ($self, $cd) = @_;
    my $c  = $self->compiler;
    my $cv = $cd->{cl_value};

    my $icd = $c->compile(
        schema       => $cv,
        #indent_level => $cd->{indent_level}+1,
        (map { $_=>$cd->{args}{$_} } qw(lang locale mark_fallback format)),
    );

    # can we say 'array of INOUNS', e.g. 'array of integers'?
    if (@{$icd->{ccls}} == 1) {
        my $c0 = $icd->{ccls}[0];
        if ($c0->{type} eq 'noun' && ref($c0->{text}) eq 'ARRAY' &&
                @{$c0->{text}} > 1 && @{$cd->{ccls}} &&
                    $cd->{ccls}[0]{type} eq 'noun') {
            for (ref($cd->{ccls}[0]{text}) eq 'ARRAY' ?
                     @{$cd->{ccls}[0]{text}} : ($cd->{ccls}[0]{text})) {
                my $fmt = $c->_xlt($cd, '%s of %s');
                $_ = sprintf $fmt, $_, $c0->{text}[1];
            }
            return;
        }
    }

    # nope, we can't
    $c->add_ccl($cd, {
        type  => 'list',
        fmt   => 'each element %(modal_verb_be)s',
        items => [
            $icd->{ccls},
        ],
        vals  => [],
    });
}

sub clause_elems {}

1;
# ABSTRACT: human's type handler for type "array"

=for Pod::Coverage ^(clause_.+|superclause_.+)$
