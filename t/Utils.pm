package t::Utils;
use strict;
use warnings;
use base qw/Exporter/;
use Test::More;
use DBI;
our @EXPORT = (@Test::More::EXPORT, 'run_test');

eval 'require File::Temp';
plan skip_all => 'this test requires File::Temp' if $@;
if ($ENV{TSM_TEST_PG}) {
    eval 'require DBD::Pg';
    plan skip_all => 'this test requires DBD::Pg' if $@;
}
else {
    eval 'require DBD::SQLite';
    plan skip_all => 'this test requires DBD::SQLite' if $@;
}

our $dbcount = 0;

sub run_test (&) {
    my $code = shift;
    local $dbcount = $dbcount+1;

    my $tmp = File::Temp->new;
    $tmp->close();
    my $dbname;
    my $dbh;

    if ($ENV{TSM_TEST_PG}) {
        my $createdb = $ENV{PGCREATEDB} || 'createdb';
        $dbname = $ENV{PGDBPREFIX} || 'schwartz';
        $dbname .= $dbcount;
        system("$createdb -E UTF-8 -q $dbname")
            and die "can't create db '$dbname' with '$createdb'";

        $dbh = DBI->connect("dbi:Pg:database=$dbname", $ENV{user}, '', {
                AutoCommit => 1,
                RaiseError => 0,
                PrintError => 0,
            }) or die $DBI::errstr;
    }
    else {
        $dbname = $tmp->filename;
        $dbh = DBI->connect("dbi:SQLite:dbname=$dbname", '', '', {
                RaiseError => 1,
                PrintError => 0,
            }) or die $DBI::err;

        # work around for DBD::SQLite's resource leak
        tie my %blackhole, 't::Utils::Blackhole';
        $dbh->{CachedKids} = \%blackhole;
    }

    init_schwartz($dbh);

    $code->($dbh); # do test

    $dbh->disconnect;

    if ($ENV{TSM_TEST_PG}) {
        my $dropdb = $ENV{PGDROPDB} || 'dropdb';
        system("$dropdb -q $dbname");
    }
}

sub init_schwartz {
    my $dbh = shift;
    my $name = $dbh->{Driver}{Name};

    my $schemafile = "schema/$name.sql";
    my $schema = do { local(@ARGV,$/)=$schemafile; <> };
    die "Schmema not found" unless $schema;
    my $prefix = $::prefix || "";
    $schema =~ s/PREFIX_/$prefix/g;

    do {
        $dbh->begin_work;
        for (split /;\s*/m, $schema) {
            $dbh->do($_);
        }
        $dbh->commit;
    };
}

{
    package t::Utils::Blackhole;
    use base qw/Tie::Hash/;
    sub TIEHASH { bless {}, shift }
    sub STORE { } # nop
    sub FETCH { } # nop
}

1;
