package App::Sticker::Cmd::search;
use strict;
use warnings;
use Moo;
use Mojo::ByteStream 'b';
extends 'App::Sticker::Cmd';

sub execute {
    my $self    = shift;
    my @matches = $self->base->db->search(@ARGV);
    my $hist_fh = $self->base->base_dir->child('last_search')->openw_utf8();

    my $i   = 0;
    my $len = length(@matches);
    for my $doc (@matches) {
        my $line =
          sprintf( "%*d %s - %s ", $len, ++$i, $doc->{url}, $doc->{title} );
        print b($line)->encode . "\n";
        print {$hist_fh} $doc->{url} . "\n";
    }
}

1;
