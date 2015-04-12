package Data::Sah::Compiler::perl;

# DATE
# VERSION

use 5.010;
use strict;
use warnings;
#use Log::Any qw($log);

use Data::Dmp qw(dmp);
use Mo qw(build default);
use String::Indent ();

extends 'Data::Sah::Compiler::Prog';

sub BUILD {
    my ($self, $args) = @_;

    $self->comment_style('shell');
    $self->indent_character(" " x 4);
    $self->var_sigil('$');
    $self->concat_op(".");
}

sub name { "perl" }

sub literal {
    dmp($_[1]);
}

sub expr {
    my ($self, $expr) = @_;
    $self->expr_compiler->perl($expr);
}

sub compile {
    my ($self, %args) = @_;

    #$self->expr_compiler->compiler->hook_var(
    #    sub {
    #        $_[0];
    #    }
    #);

    #$self->expr_compiler->compiler->hook_func(
    #    sub {
    #        my ($name, @args) = @_;
    #        die "Unknown function $name"
    #            unless $self->main->func_names->{$name};
    #        my $subname = "func_$name";
    #        $self->define_sub_start($subname);
    #        my $meth = "func_$name";
    #        $self->func_handlers->{$name}->$meth;
    #        $self->define_sub_end();
    #        $subname . "(" . join(", ", @args) . ")";
    #    }
    #);

    $self->SUPER::compile(%args);
}

sub init_cd {
    my ($self, %args) = @_;

    my $cd = $self->SUPER::init_cd(%args);

    if (my $ocd = $cd->{outer_cd}) {
        $cd->{module_statements} = $ocd->{module_statements};
    } else {
        $cd->{module_statements} = {};
    }

    $self->add_no($cd, 'warnings', ["'void'"]);

    $cd;
}

sub true { "1" }

sub false { "''" }

sub add_use {
    my ($self, $cd, $name, $imports) = @_;

    die "BUG: imports must be an arrayref"
        if defined($imports) && ref($imports) ne 'ARRAY';
    $self->add_module($cd, $name);
    $cd->{module_statements}{$name} = ['use', $imports];
}

sub add_no {
    my ($self, $cd, $name, $imports) = @_;

    die "BUG: imports must be an arrayref"
        if defined($imports) && ref($imports) ne 'ARRAY';
    $self->add_module($cd, $name);
    $cd->{module_statements}{$name} = ['no', $imports];
}

sub add_smartmatch_pragma {
    my ($self, $cd) = @_;
    $self->add_use($cd, 'experimental', ["'smartmatch'"]);
}

sub add_sun_module {
    my ($self, $cd) = @_;
    if ($cd->{args}{pp}) {
        $cd->{_sun_module} = 'Scalar::Util::Numeric::PP';
    } else {
        $cd->{_sun_module} = 'Scalar::Util::Numeric';
    }
    $self->add_module($cd, $cd->{_sun_module});
}

sub expr_defined {
    my ($self, $t) = @_;
    "defined($t)";
}

sub expr_array_subscript {
    my ($self, $at, $idxt) = @_;
    "$at->\[$idxt]";
}

sub expr_last_elem {
    my ($self, $at, $idxt) = @_;
    "$at->\[-1]";
}

sub expr_push {
    my ($self, $at, $elt) = @_;
    "push(\@{$at}, $elt)";
}

sub expr_pop {
    my ($self, $at, $elt) = @_;
    "pop(\@{$at})";
}

sub expr_push_and_pop_dpath_between_expr {
    my ($self, $et) = @_;
    join(
        "",
        "[",
        $self->expr_push('$_sahv_dpath', $self->literal(undef)), ", ", # 0
        "~~", $self->enclose_paren($et), ", ", #1 (~~ to avoid list flattening)
        $self->expr_pop('$_sahv_dpath'), # 2
        "]->[1]",
    );
}

sub expr_prefix_dpath {
    my ($self, $t) = @_;
    '(@$_sahv_dpath ? \'@\'.join("/",@$_sahv_dpath).": " : "") . ' . $t;
}

# $l //= $r
sub expr_setif {
    my ($self, $l, $r) = @_;
    "($l //= $r)";
}

sub expr_set_err_str {
    my ($self, $et, $err_expr) = @_;
    "($et //= $err_expr)";
}

sub expr_set_err_full {
    my ($self, $et, $k, $err_expr) = @_;
    "($et\->{$k}{join('/',\@\$_sahv_dpath)} //= $err_expr)";
}

sub expr_reset_err_str {
    my ($self, $et, $err_expr) = @_;
    "($et = undef, 1)";
}

sub expr_reset_err_full {
    my ($self, $et) = @_;
    "(delete($et\->{errors}{join('/',\@\$_sahv_dpath)}), 1)";
}

sub expr_log {
    my ($self, $cd, @expr) = @_;

    "\$log->tracef('[sah validator](spath=%s) %s', " .
        $self->literal($cd->{spath}).", " . join(", ", @expr) . ")";
}

# wrap statements into an expression
sub expr_block {
    my ($self, $code) = @_;
    join(
        "",
        "do {\n",
        String::Indent::indent(
            $self->indent_character,
            $code,
        ),
        "}",
    );
}

# whether block is implemented using function
sub block_uses_sub { 0 }

sub stmt_declare_local_var {
    my ($self, $v, $vt) = @_;
    if ($vt eq 'undef') {
        "my \$$v;";
    } else {
        "my \$$v = $vt;";
    }
}

sub expr_anon_sub {
    my ($self, $args, $code) = @_;
    join(
        "",
        "sub {\n",
        String::Indent::indent(
            $self->indent_character,
            join(
                "",
                ("my (".join(", ", @$args).") = \@_;\n") x !!@$args,
                $code,
            ),
        ),
        "}"
    );
}

sub stmt_require_module {
    my ($self, $mod, $cd) = @_;
    my $ms = $cd->{module_statements};

    if (!$ms->{$mod}) {
        "require $mod;";
    } elsif ($ms->{$mod}[0] eq 'use' || $ms->{$mod}[0] eq 'no') {
        my $verb = $ms->{$mod}[0];
        if (!$ms->{$mod}[1]) {
            "$verb $mod;";
        } else {
            "$verb $mod (".join(", ", @{ $ms->{$mod}[1] }).");";
        }
    }
}

sub stmt_require_log_module {
    my ($self, $mod) = @_;
    'use Log::Any qw($log);';
}

sub stmt_return {
    my $self = shift;
    if (@_) {
        "return($_[0]);";
    } else {
        'return;';
    }
}

sub expr_validator_sub {
    my ($self, %args) = @_;

    $self->check_compile_args(\%args);

    my $aref = delete $args{accept_ref};
    if ($aref) {
        $args{var_term}  = '$ref_'.$args{data_name};
        $args{data_term} = '$$ref_'.$args{data_name};
    } else {
        $args{var_term}  = '$'.$args{data_name};
        $args{data_term} = '$'.$args{data_name};
    }

    $self->SUPER::expr_validator_sub(%args);
}

sub _str2reliteral {
    require Regexp::Stringify;

    my ($self, $cd, $str) = @_;

    my $re;
    if (ref($str) eq 'Regexp') {
        $re = $str;
    } else {
        eval { $re = qr/$str/ };
        $self->_die($cd, "Invalid regex $str: $@") if $@;
    }

    Regexp::Stringify::stringify_regexp(regexp=>$re, plver=>5.010);
}

1;
# ABSTRACT: Compile Sah schema to Perl code

=for Pod::Coverage BUILD ^(after_.+|before_.+|name|expr|true|false|literal|expr_.+|stmt_.+|block_uses_sub)$

=head1 SYNOPSIS

 # see Data::Sah


=head1 DESCRIPTION

Derived from L<Data::Sah::Compiler::Prog>.


=head1 METHODS

=head2 new() => OBJ

=head3 Compilation data

This subclass adds the following compilation data (C<$cd>).

Keys which contain compilation result:

=over

=item * B<module_statements> => HASH

This hash, keyed by module name, lets the Perl compiler differentiate on the
different statements to use when loading modules, e.g.:

 {
     "Foo"      => undef,    # or does not exist
     "Bar::Baz" => ['use'],
     "Qux"      => ['use', []],
     "Quux"     => ['use', ["'a'", 123]],
     "warnings" => ['no'],
 }

will lead to these codes (in the order specified by C<< $cd->{modules} >>, BTW)
being generated:

 require Foo;
 use Bar::Baz;
 use Qux ();
 use Quux ('a', 123);
 no warnings;

=back

=head2 $c->comment($cd, @args) => STR

Generate a comment. For example, in perl compiler:

 $c->comment($cd, "123"); # -> "# 123\n"

Will return an empty string if compile argument C<comment> is set to false.

=head2 $c->compile(%args) => RESULT

Aside from Prog's arguments, this class supports these arguments:

=over

=item * pp => bool (default: 0)

If set to true, will avoid the use of XS modules in the generated code and will
opt instead to use pure-perl modules.

=back

=head2 $c->add_use($cd, $module, \@imports)

This is like C<add_module()>, but indicate that C<$module> needs to be C<use>-d
in the generated code (for example, Perl pragmas). Normally if C<add_module()>
is used, the generated code will use C<require>.

If you use C<< $c->add_use($cd, 'foo') >>, this code will be generated:

 use foo;

If you use C<< $c->add_use($cd, 'foo', ["'a'", "'b'", "123"]) >>, this code will
be generated:

 use foo ('a', 'b', 123);

If you use C<< $c->add_use($cd, 'foo', []) >>, this code will be generated:

 use foo ();

The generated statement will be added at the top (top-level lexical scope) and
duplicates are ignored. To generate multiple and lexically-scoped C<use> and
C<no> statements, e.g. like below, currently you can generate them manually:

 if (blah) {
     no warnings;
     ...
 }

=head2 $c->add_no($cd, $module)

This is the counterpart of C<add_use()>, to generate C<<no foo>> statement.

See also: C<add_use()>.

=head2 $c->add_smartmatch_pragma($cd)

Equivalent to:

 $c->add_use($cd, 'experimental', ["'smartmatch'"]);


=head1 DEVELOPER NOTES

To generate expression code that says "all subexpression must be true", you can
do:

 !defined(List::Util::first(sub { blah($_) }, "value", ...))

This is a bit harder to read than:

 !grep { !blah($_) } "value", ...

but has the advantage of the ability to shortcut on the first item that fails.

Similarly, to say "at least one subexpression must be true":

 defined(List::Util::first(sub { blah($_) }, "value", ...))

which can shortcut in contrast to:

 grep { blah($_) } "value", ...

=cut
