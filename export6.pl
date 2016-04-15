#!/usr/bin/env perl6
use v6;
use lib "~/perl6/lib";

use DBIish;
my $targetdirectory = </home/spuelrich/sync/simon-bilder>;

my $dbh = DBIish.connect("SQLite", :database</home/spuelrich/.local/share/shotwell/data/photo.db>);

my $sql = q:to/EOSQL/;
SELECT photo_id_list
FROM TagTable
WHERE name = ?
EOSQL

my $sth = $dbh.prepare($sql);
$sth.execute('Simon');
my ($photo_id_list) = $sth.allrows();
$sth.finish();

exit unless $photo_id_list;

my @ids = (map  { my $copy = $_; $copy ~~ s/thumb0*//; :16($copy) },
           grep { /^thumb/ },
           $photo_id_list.split(',')
          );

$sth = $dbh.prepare(q:to/EOSQL2/);
SELECT id, filename, exposure_time, time_created
  FROM PhotoTable WHERE rating in (5) AND id=?
EOSQL2

sub dateformatter (DateTime:D $d) { sprintf '%04d-%02d-%02d-%02d%02d%02d',
                                    $d.year, $d.month, $d.day,
                                    $d.hour, $d.minute, $d.second }
for @ids -> $id {
    $sth.execute($id);
    my %photo = $sth.row(:hash);
    next if !%photo;
    say %photo.perl;
    %photo<targetfilename> = %photo<filename>.IO.basename;
    %photo<targetfilename> ~~ s:global/\s/_/;

    %photo<targetfilename> = (DateTime.new(%photo<exposure_time>||%photo<time_created>,
                                           formatter => &dateformatter).Str()
                              ~ '-'
                              ~ %photo<targetfilename>
                             );
    #strftime(q(%F-%H%M%S-), localtime($exposuretime||$timecreated))

    say %photo;
}


=finish
__END__
use File::Copy;
use File::Path qw(make_path);
use File::Spec;
use File::Basename;
use POSIX qw(strftime);
use File::Copy;



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
