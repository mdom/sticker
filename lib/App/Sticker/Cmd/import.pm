package App::Sticker::Cmd::import;
use strict;
use warnings;
use Moo;
use Path::Tiny;
extends 'App::Sticker::Cmd';
with( 'App::Sticker::UA', 'App::Sticker::Util', 'App::Sticker::Modifier' );

sub execute {
    my $self  = shift;
    my @files = @ARGV;
    my @attrs;
    for my $file (@files) {
        my $content = path($file)->slurp_utf8;
        my $dom     = Mojo::DOM->new($content);
        my $attrs   = $dom->find('a["href"]')->map('attr')
          ->grep( sub { $_->{href} =~ /^http/ } )->to_array;
        push @attrs, @$attrs;
    }
    my %attrs = map { $self->normalize_url( $_->{href} ) => $_ } @attrs;
    my @urls = keys %attrs;

    my $urls_added = $self->add_urls( \@urls );

    my $db = $self->base->db;
    for my $url (@$urls_added) {
        my $doc = $db->get($url);
        my $url = $url->to_string;
        next unless exists $attrs{$url}->{add_date};
        $doc->{add_date} = $attrs{$url}->{add_date};
        $db->set($doc);
    }
    return;
}

1;
