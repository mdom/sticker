package App::Sticker::Cmd::search;
use strict;
use warnings;
use Moo;
use Mojo::ByteStream 'b';
extends 'App::Sticker::Cmd';

sub execute {
    my $self    = shift;
    my $matches = $self->base->db->dbh->selectall_arrayref($ARGV[0], { Slice => {} });
    my $hist_fh = $self->base->base_dir->child('last_search')->openw_utf8();

    for my $doc (@$matches) {
        my $line =
          sprintf( "%d %s - %s ", $doc->{rowid}, $doc->{url}, $doc->{title} );
        print b($line)->encode . "\n";
        print {$hist_fh} $doc->{url} . "\n";
    }
}

1;
