#!perl
use warnings;
use strict;
use t::Utils;

for my $mod (qw(DBD::Pg TAP::Harness IO::String)) {
    eval "require $mod";
    plan skip_all => "this test requires $mod" if $@;
}

unless ($ENV{PGCREATEDB}) {
    $ENV{PGCREATEDB} = `which createdb`;
    chomp $ENV{PGCREATEDB};
    plan skip_all => 'Must have PGCREATEDB set to the location of "createdb"'
        unless -x $ENV{PGCREATEDB};
    diag "Set PGCREATEDB to $ENV{PGCREATEDB}";
}

unless ($ENV{PGDROPDB}) {
    $ENV{PGDROPDB} = `which dropdb`;
    chomp $ENV{PGDROPDB};
    plan skip_all => 'Must have PGDROPDB set to the location of "dropdb"'
        unless -x $ENV{PGDROPDB};
    diag "Set PGDROPDB to $ENV{PGDROPDB}";
}

$ENV{TSM_TEST_PG} = 1;

opendir my $dir, 't' or die "can't open test dir: $!";
my @tests;
for my $t (<t/*.t>) {
    next if $t eq 't/999_postgres.t';
    next unless $t =~ /\d/; # skips POD, boilerplate, etc.
    #Test::More::diag $t;
    push @tests, $t;
}
closedir $dir;

plan tests => scalar @tests;

my $th = TAP::Harness->new({
        formatter_class => 'TAP::Formatter::NULL',
        verbosity => 1,
        callbacks => {
            after_test => sub { 
                my ($job_as_array, $parser) = @_;
                ok(!$parser->has_problems, "Pg re-test for $job_as_array->[1]");
                if ($parser->has_problems) {
                    diag "Try running $job_as_array->[0] with TSM_TEST_PG=1";
                }
            },
        },
    });
$th->runtests(@tests);

{
    package TAP::Formatter::NULL;
    use base 'TAP::Formatter::Console';

    sub new {
        my $class = shift;
        my $self = $class->SUPER::new(@_);
        $self->stdout(IO::String->new);
        return $self;
    }
}

