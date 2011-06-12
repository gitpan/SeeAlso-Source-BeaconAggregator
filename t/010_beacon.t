# -*- perl -*-

# t/010_beacon.t - check module loading and create testing directory

use Test::More tests => 13;
use Cwd 'abs_path';

BEGIN { 
  use_ok( 'SeeAlso::Source::BeaconAggregator::Maintenance' );
}

# create new database

my $dsn = "testdb";

my $use = SeeAlso::Source::BeaconAggregator::Maintenance->new(dsn => $dsn);
ok (defined $use, "created db with dsn");
isa_ok ($use, 'SeeAlso::Source::BeaconAggregator');


# load first beacon file
subtest 'load file' => sub {
	plan tests => 4;
	my ($seqno, $rec_ok, $message) = $use->loadFile("t/beacon1.txt", {_alias => 'foo'} );
	ok(defined $seqno, "load beacon file");
	ok($seqno && ($seqno > 0), "something was loaded");
	is($seqno, 1, "expected seqno");
	is($rec_ok, 3, "number of unique records loaded");
};

my $file = "t/beacon2.txt";
my $file_uri = 'file://'.abs_path($file);
# load second beacon file with update
subtest 'load uri' => sub {
	plan tests => 5;
	note "load $file as $file_uri";
	($seqno, $rec_ok) = $use->update("bar", {_uri => $file_uri} );
	ok(defined $seqno, "load beacon file from uri (update)");
	ok($seqno && ($seqno > 0), "something was loaded");
	is($seqno, 2, "expected seqno");
	ok($rec_ok  && ($rec_ok > 0), "records loaded");
	is($rec_ok, 4, "number of unique records loaded");
};

# update known files
subtest 'update' => sub {
	plan tests => 3;
	my ($seqno, $rec_ok) = $use->update(2);
        is($seqno, undef, 'file was not modified');

        ($seqno, $rec_ok) = $use->update("bar", {}, (force => 1));
	is($seqno, 3, "seqno was incremented");
	is($rec_ok, 4, "number of unique records loaded");
};



# Seqnos
subtest 'Seqnos' => sub {
	plan tests => 2;
	my @seqnos = $use->Seqnos('TARGET', '%deutsche-biographie%');
	is(scalar @seqnos, 1, 'number of targets');
	is($seqnos[0], 3, 'correct sequence met');
};


# RepoCols
subtest 'RepoCols' => sub {
	plan tests => 3;
	my @cols = $use->RepoCols();
	is(scalar @cols, 1, 'number of targets');
	is(ref($cols[0]), "HASH", 'expected result');
        my $expected = {
		1 => "foo",
		3 => "bar",
        };
        is_deeply($cols[0], $expected, 'expected RepoCols');
};

subtest 'RepoCols with args' => sub {
	plan tests => 3;
	my @cols = $use->RepoCols('REMARK', "bar");
	is(scalar @cols, 1, 'number of targets');
	is(ref($cols[0]), "HASH", 'expected result');
        my $expected = {
		3 => "Some test records",
        };
        is_deeply($cols[0], $expected, 'expected RepoCols');
};

# headerfields
subtest 'headerfield' => sub {
	plan tests => 2;
	my ($rows, @oldvals) = $use->headerfield(1, 'ONEMESSAGE');
	is($rows, 1, 'number of targets');
	is($oldvals[0], "Hit in test repo", 'correct sequence met');
};

subtest 'headerfield with args' => sub {
	plan tests => 4;
	my ($rows, @oldvals) = $use->headerfield("bar", 'INSTITUTION', 'Who Cares');
	is($rows, 1, 'number of targets');
	is($oldvals[0], undef, 'correct sequence met');
   # read back
	($rows, @oldvals) = $use->headerfield(3, 'INSTITUTION');
	is($rows, 1, 'number of targets');
	is($oldvals[0], "Who Cares", 'correct sequence met');
};


# headers
subtest 'headers' => sub {
	plan tests => 9;
#        (my $file1_uri = $file_uri) =~ s/beacon2.txt/beacon1.txt/;
        my %expected = (
        1 => [{ VERSION => 0.1,
                FORMAT => 'PND-BEACON',
                ONEMESSAGE => 'Hit in test repo',
                TARGET => 'http://d-nb.info/gnd/{ID}',
              },
              {	_seqno => 1,
		_alias => 'foo',
#		_ruri => $file1_uri,
                _mtime => 'xxxx-xx-xxTxx:xx:xxZ', _ftime => 'xxxx-xx-xxTxx:xx:xxZ', _utime => 'xxxx-xx-xxTxx:xx:xxZ',
                _counti => 3, _countu => 3,
                '-live_count_id' => 3, '-live_unique_id' => 3,
                _fstat => '0 replaced, 3 new, 0 deleted, 1 duplicate, 0 nil, 0 invalid, 0 ignored',
                _ustat => 'successfully loaded',
              }],
        3 => [{ VERSION => 0.1,
                FORMAT => 'BEACON',
                REMARK => 'Some test records',
                PREFIX => 'http://d-nb.info/gnd/{ID}',
                TARGET => 'http://www.deutsche-biographie.de/pnd{ID}.html',
                ALTTARGET => 'http://www.hls-dhs-dss.ch/textes/d/D{ALTID}.php',
                INSTITUTION => 'Who Cares',
              },
              {	_seqno => 3,
		_alias => 'bar',
		_uri => $file_uri, _ruri => $file_uri,
                _mtime => 'xxxx-xx-xxTxx:xx:xxZ', _ftime => 'xxxx-xx-xxTxx:xx:xxZ', _utime => 'xxxx-xx-xxTxx:xx:xxZ',
                _counti => 4, _countu => 3,
                '-live_count_id' => 4, '-live_unique_id' => 3,
                _fstat => '4 replaced, 0 new, 0 deleted, 2 duplicate, 0 nil, 0 invalid, 0 ignored',
                _ustat => 'successfully loaded',
              }],
        );
        while ( my ($resultref, $metaref) = $use->headers() ) {
             last unless defined $resultref;
             my $seq;
             ok($seq = $metaref->{_seqno}, 'nonzero sequence number');
             my $exp;
             ok($exp = $expected{$seq}, "expected sequence number");
             is_deeply($resultref, $exp->[0], 'expected result');
             $metaref->{_mtime} =~ s/\d/x/g if $metaref->{_mtime};
             $metaref->{_ftime} =~ s/\d/x/g if $metaref->{_ftime};
             $metaref->{_utime} =~ s/\d/x/g if $metaref->{_utime};
             is_deeply($metaref, $exp->[1], 'expected meta');
             delete $expected{$seq};
          };
        is(scalar keys %expected, 0, 'all eaten up');
  };


# headers
# listCollections
subtest 'listCollections' => sub {
	plan tests => 7;
        my %expected = (  # Seqno, Alias, Uri, Mtime, Counti, Countu
        1 => [1, "foo", undef, "...", 3, 3],
        3 => [3, "bar", $file_uri, "...", 4, 3],
        );
        while ( my @row = $use->listCollections() ) {
             my $seq;
             ok($seq = $row[0], 'nonzero sequence number');
             my $exp;
             ok($exp = $expected{$seq}, "expected sequence number");
             $row[3] =~ s/\d+/.../;
             is_deeply(\@row, $exp, 'expected result');
             delete $expected{$seq};
          };
        is(scalar keys %expected, 0, 'all eaten up');
  };



