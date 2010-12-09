package Sah::Type::Int;
# ABSTRACT: Specification for 'int' type

use Any::Moose '::Role';
use Sah::Util 'clause';
with
    'Sah::Type::Num';

our $type_names = ["int", "integer"];

=head1 CLAUSES

'Int' assumes the following role: L<Sah::Type::Num>. Consult the documentation of
the base type to see what type clauses are available.

In addition, 'int' defines these clauses:

=head2 mod => [X, Y]

Require that (data mod X) equals Y. For example, mod => [2, 1] effectively
specifies odd numbers.

=cut

clause 'mod', arg => [['int*' => {not=>0}], 'int*'];

=head2 divisible_by => INT or ARRAY

Require that data is divisible by all specified numbers.

Example:

Given schema [int=>{divisible_by=>2}], 2, 4, and 6 are valid. Given schema
[int=>{divisible_by=>[2,3]}] ), only 6 is valid.

=cut

clause 'divisible_by', arg => 'int*|((int*)[])*';

=head2 not_divisible_by => INT or ARRAY

Aliases: B<indivisible_by>

Opposite of B<divisible_by>.

=cut

clause 'not_divisible_by', alias => 'indivisible_by', arg => 'int*|((int*)[])*';

no Any::Moose;
1;
