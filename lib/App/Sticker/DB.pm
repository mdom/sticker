package App::Sticker::DB;

use strict;
use warnings;
use Moo;
use DBI;
use Mojo::JSON qw(encode_json decode_json);
use Mojo::URL;
use List::Util 'first';
use Time::Piece;

has db_file => ( is => 'ro', required => 1 );
has dbh => ( is => 'lazy' );

sub _build_dbh {
    my ($self) = @_;
    my $dbfile = $self->db_file;
    my $dbh    = DBI->connect(
        "dbi:SQLite:dbname=$dbfile",
        "", "",
        {
            RaiseError     => 1,
            sqlite_unicode => 1,
        }
    );
    return $dbh;
}

sub get {
    my ( $self, $url ) = @_;
    $self->dbh->selectrow_hashref( 'SELECT url FROM urls WHERE url = ?',
        {}, $url );
}

1;
