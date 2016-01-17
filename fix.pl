#!/usr/bin/perl
use common::sense;

use DBI;
use File::Copy;
use File::Path qw(make_path);

my $dbh = DBI->connect('dbi:SQLite:dbname=/home/spuelrich/.shotwell/data/photo.db','','',
                       { RaiseError => 1, AutoCommit => 1 });

my $sth = $dbh->prepare('SELECT id, filename from PhotoTable');
$sth->execute();
my $updatesth = $dbh->prepare('update phototable set filename=? where id=?');
my $counter = 1;
$dbh->begin_work();
while (my ($id, $filename) = $sth->fetchrow_array()) {
    if ((my $newfilename = $filename) =~ s-/home/spuelrich/Fotos/-/home/spuelrich/Bilder/-) {
        #(my $path = $newfilename) =~ s-[^/]+$--;
        #if (!-d$path) {
        #    say "create $path";
        #    make_path($path);
        #}
        #say "update path $filename -> $newfilename";
        $updatesth->execute($newfilename, $id);
        #if (-e $newfilename) {
        #    say "--- $newfilename exists";
        #}
        #else {
        #    say "copy $filename -> $newfilename";
        #    copy($filename, $newfilename);
        #}
        $counter++;
    }
    say $counter if !($counter % 100);
}
$dbh->commit();
$dbh->disconnect();
