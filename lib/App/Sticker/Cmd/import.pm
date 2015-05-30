package App::Sticker::Cmd::import;
use strict;
use warnings;
use Moo;
use MooX::Cmd;
extends 'App::Sticker::Cmd';
with( 'App::Sticker::UA', 'App::Sticker::Util', 'App::Sticker::Modifier' );

sub execute {
    my $self  = shift;
    my @files = @ARGV;
    my @all_urls;
    for my $file (@files) {
        my $content = path($file)->slurp_utf8;
        my $dom     = Mojo::DOM->new($content);
        my $urls =
          $dom->find('a["href"]')->map( attr => 'href' )
          ->grep( sub { /^http/ } )->to_array;
        push @all_urls, @$urls;
    }
    return $self->add_urls( \@all_urls );
}

1;
