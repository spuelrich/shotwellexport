#!/usr/bin/env perl
use local::lib;
use Modern::Perl;

use DBI;
use File::Copy;
use File::Path qw(make_path);
use File::Spec;
use File::Basename;
use POSIX qw(strftime);
use File::Copy;

my $targetdirectory = q(/home/spuelrich/sync/simon-bilder);

my $dbh = DBI->connect('dbi:SQLite:dbname=/home/spuelrich/.local/share/shotwell/data/photo.db','','',
                       { RaiseError => 1, AutoCommit => 1 });

$dbh->sqlite_create_function('decodephotoid', 1, sub {});

my $sql = <<'EOSQL';
SELECT photo_id_list
FROM TagTable
WHERE name = ?
EOSQL
my $photo_id_list = $dbh->selectrow_array($sql, undef, 'Simon');

my @ids = (map  { s/thumb0*//; hex }
           grep { /^thumb/ }
           split /,/, $photo_id_list || ''
          );
say "ids in tag ".scalar(@ids);

my @ratedids;
while (my @subset = splice(@ids, 0, 999)) {
    say "subset ", scalar(@subset);
    $sql = join('',
                'SELECT id, filename, exposure_time, time_created',
                '  FROM PhotoTable WHERE rating in (5) AND id IN (',
                join(',', ('?') x @subset),
                ')',
               );
    say $sql;
    push @ratedids, @{$dbh->selectall_arrayref($sql, undef, @subset)};
}

say "rated ids in tag ".scalar(@ratedids);

# say @$_ for @ratedids;

for (@ratedids) {
    my (undef, $sourcefilename, $exposuretime, $timecreated) = @$_;
    (my $basename = basename($sourcefilename)) =~ s/\s/_/g;
    my $targetfile = File::Spec->catfile($targetdirectory,
                                         strftime(q(%F-%H%M%S-), localtime($exposuretime||$timecreated))
                                         . $basename
                                        );
    say "$sourcefilename -> $targetfile";
    copy($sourcefilename, $targetfile) or warn "copy failed: $!";
}
